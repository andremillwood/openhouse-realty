import {createHash} from 'node:crypto';
import {NextRequest,NextResponse} from 'next/server';
import {createClient} from '@/lib/supabase/server';
import {createAdminClient} from '@/lib/supabase/admin';
import {sameOrigin} from '@/lib/http/origin';
import {boundedText} from '@/lib/http/body';
import {uuidPattern} from '@/lib/enquiries/validation';
import {documentFile,documentSignature} from '@/lib/documents/files';
export const runtime='nodejs';
const EVIDENCE_BUCKET='contractor-evidence';
export async function POST(request:NextRequest){
 if(!sameOrigin(request))return NextResponse.json({error:'Invalid request origin.'},{status:403});
 if(!request.headers.get('content-type')?.includes('application/json'))return NextResponse.json({error:'JSON required.'},{status:415});
 const client=await createClient();const {data:{user},error:authError}=await client.auth.getUser();if(authError||!user?.email_confirmed_at)return NextResponse.json({error:'Sign in with a verified email first.'},{status:401});
 let body;try{body=await boundedText(request,4000);}catch{return NextResponse.json({error:'Request too large.'},{status:413});}
 let input;try{input=JSON.parse(body);if(!input||typeof input!=='object'||Array.isArray(input))throw new Error();}catch{return NextResponse.json({error:'Invalid evidence request.'},{status:400});}
 if(['reserve','finish'].includes(input.action)&&(!process.env.SUPABASE_SECRET_KEY||process.env.SUPABASE_SECRET_KEY.length<30||process.env.SUPABASE_SECRET_KEY.includes('YOUR-')))return NextResponse.json({error:'Private evidence uploads are being configured. Please try later.'},{status:503});
 if(input.action==='reserve'){
  let file;try{file=documentFile(input.file_name,input.mime_type,input.size);if(!uuidPattern.test(input.offer_id||'')||!uuidPattern.test(input.request_id||''))throw new Error();}catch{return NextResponse.json({error:'Choose a valid PDF, JPEG or PNG up to 8 MB and assignment reference.'},{status:400});}
  const {data,error}=await client.rpc('reserve_contractor_evidence',{p_offer_id:input.offer_id,p_request_id:input.request_id,p_file_name:file.name,p_mime_type:file.mime,p_size:file.size});
  if(error)return NextResponse.json({error:'Unable to reserve this upload. Check assignment access, work stage and file limits.'},{status:error.code==='42501'?403:['P0001','23505','40001','40P01'].includes(error.code)?409:400});
  if(data.state==='uploaded')return NextResponse.json({id:data.id,state:data.state},{headers:{'Cache-Control':'no-store'}});
  const {data:signed,error:signError}=await client.storage.from(EVIDENCE_BUCKET).createSignedUploadUrl(data.path,{upsert:false});
  if(signError||!signed)return NextResponse.json({error:'Unable to prepare the private upload. Retry with the same file.'},{status:503});
  return NextResponse.json({id:data.id,path:data.path,token:signed.token,state:'reserved'},{headers:{'Cache-Control':'no-store'}});
 }
 if(!uuidPattern.test(input.id||'')||!['finish','withdraw'].includes(input.action))return NextResponse.json({error:'Invalid evidence action.'},{status:400});
 const {data:doc,error}=await client.from('contractor_evidence').select('id,user_id,object_path,mime_type,declared_size,state').eq('id',input.id).eq('user_id',user.id).maybeSingle();
 if(error||!doc)return NextResponse.json({error:'Evidence unavailable.'},{status:404});
 if(input.action==='withdraw'){
  const {error:withdrawError}=await client.rpc('withdraw_contractor_evidence',{p_evidence_id:doc.id});
  if(withdrawError)return NextResponse.json({error:'Unable to withdraw this evidence at its current work stage or after report submission.'},{status:withdrawError.code==='42501'?403:['23505','40001','40P01'].includes(withdrawError.code)?409:400});
  return NextResponse.json({state:'withdrawn'},{headers:{'Cache-Control':'no-store'}});
 }
 try{
  const {data:file,error:downloadError}=await client.storage.from(EVIDENCE_BUCKET).download(doc.object_path);if(downloadError||!file)throw new Error('Upload not available');
  if(file.size!==Number(doc.declared_size))return NextResponse.json({error:'Uploaded size does not match the reserved file. Withdraw it and start a new upload.'},{status:400});
  const bytes=new Uint8Array(await file.arrayBuffer());documentSignature(bytes,doc.mime_type);
  const {error:finishError}=await createAdminClient().rpc('finish_contractor_evidence',{p_actor:user.id,p_evidence_id:doc.id,p_size:file.size,p_mime_type:doc.mime_type,p_sha256:createHash('sha256').update(bytes).digest('hex')});
  if(finishError)return NextResponse.json({error:'Unable to finalize this evidence. Check work stage and reservation expiry.'},{status:409});
  return NextResponse.json({state:'uploaded'},{headers:{'Cache-Control':'no-store'}});
 }catch{return NextResponse.json({error:'Unable to verify the uploaded file. Check its format or retry after the upload finishes.'},{status:400});}
}
export async function GET(request:NextRequest){
 const client=await createClient();const {data:{user},error:authError}=await client.auth.getUser();if(authError||!user?.email_confirmed_at)return NextResponse.json({error:'Sign in first.'},{status:401});
 const id=request.nextUrl.searchParams.get('id')||'';if(!uuidPattern.test(id))return NextResponse.json({error:'Invalid evidence.'},{status:400});
 const {data:doc,error}=await client.from('contractor_evidence').select('object_path,file_name,state').eq('id',id).eq('state','uploaded').maybeSingle();
 if(error||!doc)return NextResponse.json({error:'Evidence unavailable.'},{status:404});
 const {data,error:signError}=await client.storage.from(EVIDENCE_BUCKET).createSignedUrl(doc.object_path,120,{download:doc.file_name});
 if(signError||!data)return NextResponse.json({error:'Unable to prepare the download.'},{status:503});
 return NextResponse.json({url:data.signedUrl,expiresIn:120},{headers:{'Cache-Control':'no-store'}});
}
