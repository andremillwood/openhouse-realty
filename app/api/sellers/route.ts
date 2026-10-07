import { NextRequest, NextResponse } from 'next/server';
import { sameOrigin } from '@/lib/http/origin';
import { boundedText } from '@/lib/http/body';
import { createClient } from '@/lib/supabase/server';
import { sellerInput } from '@/lib/sellers/validation';
export async function POST(request:NextRequest){
 if(!sameOrigin(request))return NextResponse.json({error:'Invalid request origin.'},{status:403});
 if(!request.headers.get('content-type')?.includes('application/json'))return NextResponse.json({error:'JSON required.'},{status:415});
 const client=await createClient();const {data:{user},error:authError}=await client.auth.getUser();
 if(authError||!user?.email_confirmed_at)return NextResponse.json({error:'Sign in with a verified email before requesting a property review.'},{status:401});
 let body;try{body=await boundedText(request,14000);}catch{return NextResponse.json({error:'Request too large or unreadable.'},{status:413});}
 let input;try{input=sellerInput(JSON.parse(body));}catch(error){return NextResponse.json({error:error instanceof Error?error.message:'Invalid request.'},{status:400});}
 const {data,error}=await client.rpc('submit_seller_request',input);
 if(error)return NextResponse.json({error:error.code==='P0001'?'You have reached the daily seller-request limit. Please try later.':'Unable to store the request. Check your selected realtor and retry.'},{status:error.code==='P0001'?429:error.code==='42501'?403:400});
 return NextResponse.json({id:data,message:'Your private property-review request is stored. The team will follow up.'},{status:201,headers:{'Cache-Control':'no-store'}});
}
