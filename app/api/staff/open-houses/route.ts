import {NextRequest,NextResponse} from 'next/server';
import {sameOrigin} from '@/lib/http/origin';
import {boundedText} from '@/lib/http/body';
import {catalogAccess} from '@/lib/staff/access';
import {openHouseInput} from '@/lib/open-houses/validation';
export async function POST(request:NextRequest){
 if(!sameOrigin(request))return NextResponse.json({error:'Invalid request origin.'},{status:403});if(!request.headers.get('content-type')?.includes('application/json'))return NextResponse.json({error:'JSON required.'},{status:415});
 const {client,user,membership}=await catalogAccess(['admin','realtor','manager']);if(!user)return NextResponse.json({error:'Verified staff sign-in required.'},{status:401});if(!membership)return NextResponse.json({error:'Organization staff required.'},{status:403});
 let body;try{body=await boundedText(request,6000);}catch{return NextResponse.json({error:'Request too large.'},{status:413});}let input;try{input=openHouseInput(JSON.parse(body));}catch(error){return NextResponse.json({error:error instanceof Error?error.message:'Check event details.'},{status:400});}
 const {data,error}=await client.rpc('author_open_house_event',input);if(error){const status=error.code==='42501'?403:['40001','23505','40P01'].includes(error.code)?409:400;return NextResponse.json({error:status===403?'A published listing and event in your organization are required.':status===409?'The event changed, or its property/host has another appointment. Refresh before retrying.':'Check the approved capacity, future event window and resolution reason. Events can be completed only after their end.'},{status});}
 return NextResponse.json(data,{headers:{'Cache-Control':'no-store'}});
}
