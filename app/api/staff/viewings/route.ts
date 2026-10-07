import { NextRequest,NextResponse } from 'next/server';
import { catalogAccess } from '@/lib/staff/access';
import { sameOrigin } from '@/lib/http/origin';
import { boundedText } from '@/lib/http/body';
import { slotInput } from '@/lib/viewings/validation';
export async function POST(request:NextRequest){
 if(!sameOrigin(request))return NextResponse.json({error:'Invalid request origin.'},{status:403});
 if(!request.headers.get('content-type')?.includes('application/json'))return NextResponse.json({error:'JSON required.'},{status:415});
 const {client,user,membership}=await catalogAccess(['admin','realtor','manager']);
 if(!user)return NextResponse.json({error:'Sign in first.'},{status:401});
 if(!membership)return NextResponse.json({error:'Viewing staff access required.'},{status:403});
 let input;try{input=slotInput(JSON.parse(await boundedText(request,2000)));}catch(error){return NextResponse.json({error:error instanceof Error?error.message:'Invalid availability.'},{status:400});}
 const {data,error}=await client.rpc('manage_viewing_slot',input);
 if(error)return NextResponse.json({error:error.code==='P0001'?'This property or host has a conflicting appointment, or the slot still has an active viewing.':'Unable to save availability. Check the property, future time and your access.'},{status:error.code==='P0001'?409:400});
 return NextResponse.json({id:data},{headers:{'Cache-Control':'no-store'}});
}
