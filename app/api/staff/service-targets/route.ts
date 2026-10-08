import {NextRequest,NextResponse} from 'next/server';
import {sameOrigin} from '@/lib/http/origin';
import {boundedText} from '@/lib/http/body';
import {catalogAccess} from '@/lib/staff/access';
import {serviceTargetInput} from '@/lib/staff/service-targets';
import {uuidPattern} from '@/lib/enquiries/validation';
const reply=(body:unknown,status=200)=>NextResponse.json(body,{status,headers:{'Cache-Control':'private, no-store'}});
export async function POST(request:NextRequest){
 if(!sameOrigin(request))return reply({error:'Invalid request origin.'},403);
 if(!request.headers.get('content-type')?.includes('application/json'))return reply({error:'JSON required.'},415);
 let access;try{access=await catalogAccess(['admin','manager']);}catch{return reply({error:'Management access could not be checked. Retry shortly.'},503);}
 const {client,user,membership}=access;if(!user)return reply({error:'Verified sign-in required.'},401);if(!membership)return reply({error:'Organization management access required.'},403);
 let body;try{body=await boundedText(request,3000);}catch{return reply({error:'Request too large.'},413);}
 let input;try{input=serviceTargetInput(JSON.parse(body));}catch(error){return reply({error:error instanceof Error?error.message:'Check the service target.'},400);}
 try{
  const {data,error}=await client.rpc('record_work_order_service_target',input);
  if(error){const status=error.code==='42501'?403:['40001','23505','40P01'].includes(error.code)?409:error.code==='22023'?400:503;return reply({error:status===403?'Verified organization manager required.':status===409?'The work order or target changed. Refresh before retrying.':status===400?'Approve an explained target with a future date, or clear it explicitly.':'Target could not be confirmed. Retry the same request.'},status);}
  const dueMatches=input.p_due_at===null?data?.due_at===null:typeof data?.due_at==='string'&&Number.isFinite(Date.parse(data.due_at))&&Date.parse(data.due_at)===Date.parse(input.p_due_at);
  if(!data||typeof data.id!=='string'||!uuidPattern.test(data.id)||data.work_order_id!==input.p_work_order_id||data.work_order_version!==input.p_expected_work_order_version||data.kind!==input.p_kind||data.version!==input.p_expected_version+1||data.action!==input.p_action||!dueMatches)return reply({error:'Target could not be confirmed. Retry the same request.'},503);
  return reply({id:data.id,work_order_id:data.work_order_id,work_order_version:data.work_order_version,kind:data.kind,version:data.version,action:data.action,due_at:input.p_due_at});
 }catch{return reply({error:'Target could not be confirmed. Retry the same request.'},503);}
}
