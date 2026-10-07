import {NextRequest,NextResponse} from 'next/server';
import {sameOrigin} from '@/lib/http/origin';
import {boundedText} from '@/lib/http/body';
import {createClient} from '@/lib/supabase/server';
import {leaseReviewInput} from '@/lib/leases/review';
import {uuidPattern} from '@/lib/enquiries/validation';
const reply=(body:unknown,status=200)=>NextResponse.json(body,{status,headers:{'Cache-Control':'private, no-store'}});
export async function POST(request:NextRequest){
 if(!sameOrigin(request))return reply({error:'Invalid request origin.'},403);
 if(!request.headers.get('content-type')?.includes('application/json'))return reply({error:'JSON required.'},415);
 let client;try{client=await createClient();const {data:{user},error}=await client.auth.getUser();if(error||!user?.email_confirmed_at)return reply({error:'Verified sign-in required.'},401);}catch{return reply({error:'Access could not be checked. Retry shortly.'},503);}
 let body;try{body=await boundedText(request,10000);}catch{return reply({error:'Request too large.'},413);}
 let input;try{input=leaseReviewInput(JSON.parse(body));}catch(error){return reply({error:error instanceof Error?error.message:'Check the review response.'},400);}
 try{const {data,error}=await client.rpc('review_rental_lease_summary',input);
  if(error){const status=error.code==='42501'?403:['40001','23505','40P01'].includes(error.code)?409:error.code==='22023'?400:error.code==='P0001'?429:503;return reply({error:status===403?'Verified applicant or independent organization staff access required.':status===409?'The summary or conversation changed. Refresh before responding.':status===400?'Check your message, current contact and review-only acknowledgment.':status===429?'Daily response limit reached. Try again later.':'Response could not be confirmed. Retry the same request.'},status);}
  if(!data||typeof data.id!=='string'||!uuidPattern.test(data.id)||data.release_id!==input.p_release_id||data.version!==input.p_expected_version+1||data.action!==input.p_action)return reply({error:'Response could not be confirmed. Retry the same request.'},503);
  return reply({id:data.id,release_id:data.release_id,version:data.version,action:data.action});
 }catch{return reply({error:'Response could not be confirmed. Retry the same request.'},503);}
}
