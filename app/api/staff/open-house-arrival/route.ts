import {NextRequest,NextResponse} from 'next/server';
import {sameOrigin} from '@/lib/http/origin';
import {boundedText} from '@/lib/http/body';
import {catalogAccess} from '@/lib/staff/access';
import {arrivalInput} from '@/lib/open-houses/arrival-validation';
export async function POST(request:NextRequest){
 if(!sameOrigin(request))return NextResponse.json({error:'Invalid request origin.'},{status:403});if(!request.headers.get('content-type')?.includes('application/json'))return NextResponse.json({error:'JSON required.'},{status:415});
 const {client,user,membership}=await catalogAccess(['admin','realtor','manager']);if(!user)return NextResponse.json({error:'Verified staff sign-in required.'},{status:401});if(!membership)return NextResponse.json({error:'Organization staff required.'},{status:403});
 let body;try{body=await boundedText(request,5500);}catch{return NextResponse.json({error:'Request too large.'},{status:413});}let input;try{input=arrivalInput(JSON.parse(body));}catch(error){return NextResponse.json({error:error instanceof Error?error.message:'Check arrival instructions.'},{status:400});}
 const {data,error}=await client.rpc('author_open_house_arrival',input);if(error){const status=error.code==='42501'?403:['40001','40P01','23505'].includes(error.code)?409:400;return NextResponse.json({error:status===403?'A published upcoming event in your organization is required.':status===409?'Arrival instructions changed. Refresh before retrying.':'Check the approved meeting instructions, paired coordinates and change reason.'},{status});}
 return NextResponse.json(data,{headers:{'Cache-Control':'private, no-store'}});
}
