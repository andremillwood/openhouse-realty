import { NextRequest,NextResponse } from 'next/server';
import { sameOrigin } from '@/lib/http/origin';
import { boundedText } from '@/lib/http/body';
import { catalogAccess } from '@/lib/staff/access';
import { sellerTransition,sellerHandoff } from '@/lib/sellers/validation';
export async function PATCH(request:NextRequest){
 if(!sameOrigin(request))return NextResponse.json({error:'Invalid request origin.'},{status:403});
 if(!request.headers.get('content-type')?.includes('application/json'))return NextResponse.json({error:'JSON required.'},{status:415});
 const {client,user,membership}=await catalogAccess(['admin','realtor','manager']);
 if(!user)return NextResponse.json({error:'Sign in first.'},{status:401});if(!membership)return NextResponse.json({error:'Staff access required.'},{status:403});
 let input;try{input=sellerTransition(JSON.parse(await boundedText(request,4000)));}catch{return NextResponse.json({error:'Check the stage and shared follow-up reason.'},{status:400});}
 const {data,error}=await client.rpc('transition_seller_request',input);
 if(error)return NextResponse.json({error:error.code==='40001'?'This request changed. Refresh before retrying.':'Unable to record this stage. Check access and follow the review sequence.'},{status:error.code==='40001'?409:error.code==='42501'?403:400});
 return NextResponse.json({status:data},{headers:{'Cache-Control':'no-store'}});
}
export async function POST(request:NextRequest){
 if(!sameOrigin(request))return NextResponse.json({error:'Invalid request origin.'},{status:403});
 if(!request.headers.get('content-type')?.includes('application/json'))return NextResponse.json({error:'JSON required.'},{status:415});
 const {client,user,membership}=await catalogAccess();
 if(!user)return NextResponse.json({error:'Sign in first.'},{status:401});if(!membership)return NextResponse.json({error:'Catalog authoring access required.'},{status:403});
 let input;try{input=sellerHandoff(JSON.parse(await boundedText(request,6000)));}catch{return NextResponse.json({error:'Check the approved proposal and public draft details.'},{status:400});}
 const {data,error}=await client.rpc('prepare_seller_listing',input);
 if(error)return NextResponse.json({error:error.code==='P0001'?'This proposal already has a draft. Refresh and open its existing listing.':'Unable to prepare the draft. Check access, proposal stage and seller approval.'},{status:error.code==='P0001'||error.code==='23505'?409:error.code==='42501'?403:400});
 return NextResponse.json(data,{status:201,headers:{'Cache-Control':'no-store'}});
}
