import {NextRequest,NextResponse} from 'next/server';
import {sameOrigin} from '@/lib/http/origin';
import {boundedText} from '@/lib/http/body';
import {catalogAccess} from '@/lib/staff/access';
import {moveInPreparationInput} from '@/lib/leases/move-in';
import {uuidPattern} from '@/lib/enquiries/validation';
const reply=(body:unknown,status=200)=>NextResponse.json(body,{status,headers:{'Cache-Control':'private, no-store'}});
export async function POST(request:NextRequest){
 if(!sameOrigin(request))return reply({error:'Invalid request origin.'},403);
 if(!request.headers.get('content-type')?.includes('application/json'))return reply({error:'JSON required.'},415);
 let access;try{access=await catalogAccess(['admin','realtor','manager']);}catch{return reply({error:'Staff access could not be checked. Retry shortly.'},503);}
 const {client,user,membership}=access;if(!user)return reply({error:'Verified staff sign-in required.'},401);if(!membership)return reply({error:'Organization staff required.'},403);
 let body;try{body=await boundedText(request,3000);}catch{return reply({error:'Request too large.'},413);}
 let input;try{input=moveInPreparationInput(JSON.parse(body));}catch(error){return reply({error:error instanceof Error?error.message:'Check the move-in preparation.'},400);}
 try{
  const {data,error}=await client.rpc('record_move_in_preparation',input);
  if(error){const status=error.code==='42501'?403:['40001','23505','40P01'].includes(error.code)?409:error.code==='22023'?400:503;return reply({error:status===403?'Independent verified organization staff required.':status===409?'The move-in preparation or preparation changed. Refresh before retrying.':status===400?'Approve preparation and provide a reason.':'Preparation could not be confirmed. Retry the same request.'},status);}
  if(!data||typeof data.id!=='string'||!uuidPattern.test(data.id)||data.draft_id!==input.p_draft_id||data.kind!==input.p_kind||data.version!==input.p_expected_version+1||data.state!==input.p_state)return reply({error:'Preparation could not be confirmed. Retry the same request.'},503);
  return reply({id:data.id,draft_id:data.draft_id,kind:data.kind,version:data.version,state:data.state});
 }catch{return reply({error:'Preparation could not be confirmed. Retry the same request.'},503);}
}
