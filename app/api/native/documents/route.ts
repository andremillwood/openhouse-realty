import {createHash} from 'node:crypto';
import {NextRequest,NextResponse} from 'next/server';
import {nativeServerIdentity,NativeAuthFailure} from '@/lib/supabase/native-server';
import {createAdminClient} from '@/lib/supabase/admin';
import {boundedText} from '@/lib/http/body';
import {uuidPattern} from '@/lib/enquiries/validation';
import {DOCUMENT_BUCKET,documentFile,documentKinds,documentSignature} from '@/lib/documents/files';
export const runtime='nodejs';
const json=(body:unknown,status=200)=>NextResponse.json(body,{status,headers:{'Cache-Control':'private, no-store'}});
const uncertain=()=>json({error:'The upload could not be confirmed. Retry the same file request or check your document records.'},503);
export async function POST(request:NextRequest){
 let identity;try{identity=await nativeServerIdentity(request);}catch(error){return json({error:'Verified account access could not be confirmed.'},error instanceof NativeAuthFailure?error.status:503);}
 if(!request.headers.get('content-type')?.includes('application/json'))return json({error:'JSON required.'},415);
 let input;try{input=JSON.parse(await boundedText(request,4000));if(!input||typeof input!=='object'||Array.isArray(input))throw Error();}catch{return json({error:'Invalid document request.'},400);}
 const {client,user}=identity;
 if(!process.env.SUPABASE_SECRET_KEY)return json({error:'Private document verification is being configured.'},503);
 try{
  if(input.action==='reserve'){
   let file;try{file=documentFile(input.file_name,input.mime_type,input.size);if(!uuidPattern.test(input.application_id||'')||!uuidPattern.test(input.request_id||'')||!documentKinds.includes(input.kind))throw Error();}catch{return json({error:'Choose a valid PDF, JPEG or PNG up to 8 MB and document category.'},400);}
   const owned=await client.from('rental_applications').select('id').eq('id',input.application_id).eq('user_id',user.id).maybeSingle();if(owned.error)return uncertain();if(!owned.data)return json({error:'Application unavailable.'},404);
   const result=await client.rpc('reserve_application_document',{p_application_id:input.application_id,p_request_id:input.request_id,p_kind:input.kind,p_file_name:file.name,p_mime_type:file.mime,p_size:file.size});
   if(result.error){if(['42501','22023','22P02','P0001'].includes(result.error.code))return json({error:'Upload is unavailable at this application stage or limit.'},409);return uncertain();}
   const r=result.data;if(!r||!uuidPattern.test(r.id||'')||!['reserved','uploaded'].includes(r.state))return uncertain();
   if(r.state==='uploaded')return json({id:r.id,state:'uploaded'});
   if(typeof r.path!=='string'||!r.path)return uncertain();
   const signed=await client.storage.from(DOCUMENT_BUCKET).createSignedUploadUrl(r.path,{upsert:false});if(signed.error||!signed.data||typeof signed.data.token!=='string'||!signed.data.token)return uncertain();
   return json({id:r.id,state:'reserved',path:r.path,token:signed.data.token});
  }
  if(input.action!=='finish'||!uuidPattern.test(input.id||''))return json({error:'Invalid document action.'},400);
  const doc=await client.from('application_documents').select('id,application_id,user_id,object_path,mime_type,declared_size,state').eq('id',input.id).eq('user_id',user.id).maybeSingle();if(doc.error)return uncertain();if(!doc.data)return json({error:'Document unavailable.'},404);const d=doc.data;
  const owned=await client.from('rental_applications').select('id').eq('id',d.application_id).eq('user_id',user.id).maybeSingle();if(owned.error)return uncertain();if(!owned.data)return json({error:'Application unavailable.'},404);
  if(d.state==='uploaded')return json({id:d.id,state:'uploaded'});
  if(d.state!=='reserved')return json({error:'This document cannot be finalized.'},409);
  const stored=await client.storage.from(DOCUMENT_BUCKET).download(d.object_path);if(stored.error||!stored.data)return uncertain();
  const file=stored.data;if(file.size!==Number(d.declared_size)||file.size>8*1024*1024)return json({error:'Uploaded size does not match its reservation. Withdraw the document and start again.'},400);
  const bytes=new Uint8Array(await file.arrayBuffer());try{documentSignature(bytes,d.mime_type);}catch{return json({error:'The stored file format could not be verified. Withdraw it and choose a valid file.'},400);}
  // Revalidate the same actor immediately before trusted certification.
  const current=await client.auth.getUser();if(current.error||current.data.user?.id!==user.id||!current.data.user.email_confirmed_at)return uncertain();
  const finished=await createAdminClient().rpc('finish_application_document',{p_actor:user.id,p_document_id:d.id,p_size:file.size,p_mime_type:d.mime_type,p_sha256:createHash('sha256').update(bytes).digest('hex')});if(finished.error)return uncertain();
  const confirmed=await client.from('application_documents').select('id,state').eq('id',d.id).eq('user_id',user.id).maybeSingle();if(confirmed.error||!confirmed.data||confirmed.data.id!==d.id||confirmed.data.state!=='uploaded')return uncertain();
  return json({id:d.id,state:'uploaded'});
 }catch{return uncertain();}
}
