import { NextRequest,NextResponse } from 'next/server';
import { createClient } from '@/lib/supabase/server';
import { sameOrigin } from '@/lib/http/origin';
import { boundedText } from '@/lib/http/body';
import { uuidPattern } from '@/lib/enquiries/validation';
import { viewingRequestInput,viewingTransitionInput } from '@/lib/viewings/validation';
const json=(body:unknown,status:number)=>NextResponse.json(body,{status,headers:{'Cache-Control':'private, no-store'}});
const unavailable=()=>json({error:'The viewing update could not be confirmed. Check your account before choosing another time.'},503);
async function handle(request:NextRequest,transition:boolean){
 if(!sameOrigin(request))return json({error:'Invalid request origin.'},403);
 if(!request.headers.get('content-type')?.includes('application/json'))return json({error:'JSON required.'},415);
 let client:Awaited<ReturnType<typeof createClient>>;let userId:string;
 try{client=await createClient();const {data:{user},error:authError}=await client.auth.getUser();if(authError||!user?.email_confirmed_at)return json({error:'Sign in with your verified email first.'},401);userId=user.id;}catch{return unavailable();}
 let raw;try{raw=JSON.parse(await boundedText(request,3000));}catch{return json({error:'Invalid or oversized request.'},400);}
 let input;try{input=transition?viewingTransitionInput(raw):viewingRequestInput(raw);}catch(error){return json({error:error instanceof Error?error.message:'Invalid viewing request.'},400);}
 try{
  if(transition){
   const {data,error}=await client.rpc('transition_viewing',input);
   if(error&&!['42501','22023','P0001','40001','23505','40P01'].includes(error.code))return unavailable();
  if(error)return json({error:error.code==='42501'?'This action requires authorized staff or the viewing owner.':'This viewing cannot change now. Refresh its status and try again.'},error.code==='42501'?403:409);
   if(!['requested','confirmed','completed','cancelled','no_show','expired'].includes(data))return unavailable();
   return NextResponse.json({status:data,...(data==='expired'?{error:'The confirmation window expired. Choose a new available time.'}:{})},{status:data==='expired'?409:200,headers:{'Cache-Control':'private, no-store'}});
  }
  const {data,error}=await client.rpc('request_viewing',input);
   if(error&&!['42501','22023','22P02','P0001','23505','40001','40P01'].includes(error.code))return unavailable();
  if(error)return json({error:['P0001','23505','40001','40P01'].includes(error.code)?'This time is unavailable, overlaps a viewing or open-house RSVP, or your request limit has been reached. Refresh your appointments and choose another time.':'Unable to request this viewing. Check the property, time and your details.'},['P0001','23505','40001','40P01'].includes(error.code)?409:400);
  if(typeof data!=='string'||!uuidPattern.test(data))return unavailable();
  const {data:stored,error:storedError}=await client.from('viewings').select('status').eq('id',data).eq('user_id',userId).maybeSingle();
  if(storedError||!stored||!['requested','confirmed','completed','cancelled','no_show','expired'].includes(stored.status))return unavailable();
  return NextResponse.json({id:data,status:stored?.status||'requested',message:stored?.status==='confirmed'?'Your viewing is confirmed. Check your account for details.':stored&&stored.status!=='requested'?'This request already has an updated status. Check your account before choosing another time.':'Your viewing request is stored. It is not confirmed until the team approves it.'},{status:201,headers:{'Cache-Control':'private, no-store'}});
 }catch{return unavailable();}
}
export async function POST(request:NextRequest){return handle(request,false);}
export async function PATCH(request:NextRequest){return handle(request,true);}
