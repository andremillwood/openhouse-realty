import {createHash} from 'node:crypto';
import {NextRequest,NextResponse} from 'next/server';
import {catalogAccess} from '@/lib/staff/access';
import {createAdminClient} from '@/lib/supabase/admin';
import {sameOrigin} from '@/lib/http/origin';
import {boundedText} from '@/lib/http/body';
import {invoiceEvidenceInput,INVOICE_EVIDENCE_BUCKET} from '@/lib/finance/invoice-evidence';
import {documentSignature} from '@/lib/documents/files';
export const runtime='nodejs';
const headers={'Cache-Control':'private, no-store'};
const json=(body:unknown,status=200)=>NextResponse.json(body,{status,headers});
function unavailable(code:string|undefined){
 const status=code==='42501'?403:['23505','40001','40P01'].includes(code||'')?409:['22023','22P02','23503'].includes(code||'')?400:503;
 return json({error:status===503?'Evidence could not be saved. Retry the same request.':'Check invoice access, review stage, reservation expiry and file details.'},status);
}
function certificationConfigured(){const key=process.env.SUPABASE_SECRET_KEY;return !!key&&key.length>=30&&!key.includes('YOUR-');}
export async function POST(request:NextRequest){
 if(!sameOrigin(request))return json({error:'Invalid request origin.'},403);
 if(!request.headers.get('content-type')?.includes('application/json'))return json({error:'JSON required.'},415);
 const {client,user,membership}=await catalogAccess(['admin','manager','finance']);
 if(!user)return json({error:'Verified sign-in required.'},401);
 if(!membership)return json({error:'Organization invoice staff required.'},403);
 let body;try{body=await boundedText(request,4000);}catch{return json({error:'Request too large.'},413);}
 let input;try{input=invoiceEvidenceInput(JSON.parse(body));}catch(error){return json({error:error instanceof Error?error.message:'Check the invoice evidence details.'},400);}
 if(input.action==='download')return json({error:'Use the private download link.'},400);
 if(['reserve','finish'].includes(input.action)&&!certificationConfigured())return json({error:'Private invoice uploads are being configured. Please try later.'},503);
 if(input.action==='reserve'){
  const {data,error}=await client.rpc('reserve_invoice_evidence',{p_invoice_id:input.invoice_id,p_request_id:input.request_id,p_kind:input.kind,p_file_name:input.file_name,p_mime_type:input.mime_type,p_size:input.size});
  if(error)return unavailable(error.code);
  if(!data?.id||!data?.path)return json({error:'Unable to prepare this reservation. Retry the same file.'},503);
  if(data.state==='uploaded')return json({id:data.id,state:'uploaded'});
  const {data:signed,error:signError}=await client.storage.from(INVOICE_EVIDENCE_BUCKET).createSignedUploadUrl(data.path,{upsert:false});
  if(signError||!signed?.token)return json({error:'Unable to prepare the private upload. Retry the same file.'},503);
  return json({id:data.id,path:data.path,token:signed.token,state:'reserved'});
 }
 const {data:doc,error}=await client.from('vendor_invoice_evidence').select('id,user_id,object_path,mime_type,declared_size,state').eq('id',input.id).eq('organization_id',membership.organization_id).eq('user_id',user.id).maybeSingle();
 if(error)return json({error:'Unable to load invoice evidence. Please retry.'},503);
 if(!doc)return json({error:'Evidence unavailable.'},404);
 if(input.action==='withdraw'){
  const {error:withdrawError}=await client.rpc('withdraw_invoice_evidence',{p_evidence_id:doc.id});
  return withdrawError?unavailable(withdrawError.code):json({state:'withdrawn'});
 }
 if(!['reserved','uploaded'].includes(doc.state))return json({error:'Start a new file reservation.'},409);
 const {data:file,error:downloadError}=await client.storage.from(INVOICE_EVIDENCE_BUCKET).download(doc.object_path);
 if(downloadError||!file)return json({error:'Upload not available for verification. Retry after the upload finishes.'},503);
 if(file.size!==Number(doc.declared_size))return json({error:'Uploaded size does not match the reservation. Withdraw it and choose a new file.'},400);
 let bytes:Uint8Array;
 try{bytes=new Uint8Array(await file.arrayBuffer());documentSignature(bytes,doc.mime_type);}catch{return json({error:'Uploaded file does not match its stated format. Withdraw it and choose a valid file.'},400);}
 try{
  const {error:finishError}=await createAdminClient().rpc('finish_invoice_evidence',{p_actor:user.id,p_evidence_id:doc.id,p_size:file.size,p_mime_type:doc.mime_type,p_sha256:createHash('sha256').update(bytes).digest('hex')});
  return finishError?unavailable(finishError.code):json({state:'uploaded'});
 }catch{return json({error:'File certification is temporarily unavailable. Retry the same file.'},503);}
}
export async function GET(request:NextRequest){
 const {client,user,membership}=await catalogAccess(['admin','manager','finance']);
 if(!user)return json({error:'Verified sign-in required.'},401);
 if(!membership)return json({error:'Organization invoice staff required.'},403);
 let input;try{input=invoiceEvidenceInput({action:'download',id:request.nextUrl.searchParams.get('id')});}catch{return json({error:'Invalid evidence reference.'},400);}
 if(input.action!=='download')return json({error:'Invalid evidence action.'},400);
 const {data:doc,error}=await client.from('vendor_invoice_evidence').select('object_path,file_name,state').eq('id',input.id).eq('organization_id',membership.organization_id).eq('state','uploaded').maybeSingle();
 if(error)return json({error:'Unable to load invoice evidence. Please retry.'},503);
 if(!doc)return json({error:'Evidence unavailable.'},404);
 const {data,error:signError}=await client.storage.from(INVOICE_EVIDENCE_BUCKET).createSignedUrl(doc.object_path,120,{download:doc.file_name});
 if(signError||!data?.signedUrl)return json({error:'Unable to prepare the private download. Please retry.'},503);
 return json({url:data.signedUrl,expiresIn:120});
}
