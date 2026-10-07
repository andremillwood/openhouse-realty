import { sameOrigin } from '@/lib/http/origin';
import { NextRequest, NextResponse } from 'next/server';
import { createClient } from '@/lib/supabase/server';
import { boundedText } from '@/lib/http/body';
import { enquiryInput, uuidPattern } from '@/lib/enquiries/validation';
const json=(body:unknown,status:number)=>NextResponse.json(body,{status,headers:{'Cache-Control':'private, no-store'}});
const unconfirmed=()=>json({error:'Your enquiry could not be confirmed. Retry the same request or check your account.'},503);
export async function POST(request:NextRequest) {
  if(!sameOrigin(request))return json({error:'Invalid request origin.'},403);
  if(!request.headers.get('content-type')?.includes('application/json'))return json({error:'JSON required.'},415);
  let client:Awaited<ReturnType<typeof createClient>>;
  try{client=await createClient();const {data:{user},error:authError}=await client.auth.getUser();if(authError||!user?.email_confirmed_at)return json({error:'Sign in with your verified email before submitting.'},401);}catch{return json({error:'Account access could not be confirmed. Please try again.'},503);}
  let text:string;try{text=await boundedText(request,12000);}catch{return json({error:'Enquiry too large or unreadable.'},413);}
  let input;try{input=enquiryInput(JSON.parse(text));}catch(error){return json({error:error instanceof Error?error.message:'Invalid enquiry.'},400);}
  try{
    const {data,error}=await client.rpc('submit_enquiry',input);
    if(error){
      if(error.code==='P0001')return json({error:'You’ve reached the enquiry limit. Please try again later.'},429);
      if(error.code==='42501')return json({error:'Sign in with your verified email before submitting.'},401);
      if(['22023','22P02'].includes(error.code))return json({error:'Check your details. The property or realtor may be unavailable.'},400);
      return unconfirmed();
    }
    if(typeof data!=='string'||!uuidPattern.test(data))return unconfirmed();
    return json({id:data,message:'Your enquiry is stored. The team will follow up; any viewing requires confirmation.'},201);
  }catch{return unconfirmed();}
}
