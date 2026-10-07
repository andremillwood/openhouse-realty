import {createHash} from 'node:crypto';
import {NextRequest,NextResponse} from 'next/server';
import {nativeServerIdentity,NativeAuthFailure} from '@/lib/supabase/native-server';
import {uuidPattern} from '@/lib/enquiries/validation';
import {createAdminClient} from '@/lib/supabase/admin';
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
 let identity;try{identity=await nativeServerIdentity(request);}catch(error){return json({error:'Verified account access could not be confirmed.'},error instanceof NativeAuthFailure?error.status:503);}
 if(!request.headers.get('content-type')?.includes('application/json'))return json({error:'JSON required.'},415);
 const {client,user}=identity;const member=await client.from('staff_accounts').select('user_id,organization_id,role,membership_revision').eq('user_id',user.id).maybeSingle();
 if(member.error)return json({error:'Invoice membership unavailable.'},503);const membership=member.data;
 if(!membership||membership.user_id!==user.id||!uuidPattern.test(membership.organization_id)||!uuidPattern.test(membership.membership_revision)||!['admin','manager','finance'].includes(membership.role))return json({error:'Organization invoice staff required.'},403);
 const unchanged=async()=>{try{const fresh=await nativeServerIdentity(request);if(fresh.user.id!==user.id)return false;const r=await fresh.client.from('staff_accounts').select('user_id,organization_id,role,membership_revision').eq('user_id',user.id).maybeSingle();return !r.error&&r.data?.user_id===user.id&&r.data.organization_id===membership.organization_id&&r.data.role===membership.role&&r.data.membership_revision===membership.membership_revision;}catch{return false;}};
 let body;try{body=await boundedText(request,4000);}catch{return json({error:'Request too large.'},413);}
 let input;try{input=invoiceEvidenceInput(JSON.parse(body));}catch(error){return json({error:error instanceof Error?error.message:'Check the invoice evidence details.'},400);}
 if(input.action==='download')return json({error:'Use the private download link.'},400);
 if(['reserve','finish'].includes(input.action)&&!certificationConfigured())return json({error:'Private invoice uploads are being configured. Please try later.'},503);
 if(input.action==='reserve'){
  const {data,error}=await client.rpc('reserve_invoice_evidence',{p_invoice_id:input.invoice_id,p_request_id:input.request_id,p_kind:input.kind,p_file_name:input.file_name,p_mime_type:input.mime_type,p_size:input.size});
  if(error)return unavailable(error.code);
  if(!data||!uuidPattern.test(data.id||'')||!['reserved','uploaded'].includes(data.state)||typeof data.path!=='string'||data.path!==input.invoice_id+'/'+data.id+(input.mime_type==='application/pdf'?'.pdf':input.mime_type==='image/jpeg'?'.jpg':'.png'))return json({error:'Unable to prepare this reservation. Retry the same file.'},503);
  if(data.state==='uploaded')return json({id:data.id,state:'uploaded'});
  const {data:signed,error:signError}=await client.storage.from(INVOICE_EVIDENCE_BUCKET).createSignedUploadUrl(data.path,{upsert:false});
  if(signError||!signed?.token)return json({error:'Unable to prepare the private upload. Retry the same file.'},503);
  if(!await unchanged())return json({error:'Invoice access changed. Retry the same request.'},503);
  return json({id:data.id,path:data.path,token:signed.token,state:'reserved'});
 }
 const {data:doc,error}=await client.from('vendor_invoice_evidence').select('id,organization_id,user_id,object_path,mime_type,declared_size,state').eq('id',input.id).eq('organization_id',membership.organization_id).eq('user_id',user.id).maybeSingle();
 if(error)return json({error:'Unable to load invoice evidence. Please retry.'},503);
 if(!doc||doc.id!==input.id||doc.user_id!==user.id||doc.organization_id!==membership.organization_id)return json({error:'Evidence unavailable.'},404);
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
 if(!await unchanged())return json({error:'Invoice access changed. Retry the same request.'},503);
 try{
  const {error:finishError}=await createAdminClient().rpc('finish_invoice_evidence',{p_actor:user.id,p_evidence_id:doc.id,p_size:file.size,p_mime_type:doc.mime_type,p_sha256:createHash('sha256').update(bytes).digest('hex')});
  return finishError?unavailable(finishError.code):json({state:'uploaded'});
 }catch{return json({error:'File certification is temporarily unavailable. Retry the same file.'},503);}
}
