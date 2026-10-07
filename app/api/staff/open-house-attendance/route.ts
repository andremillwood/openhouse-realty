import {NextRequest,NextResponse} from 'next/server';
import {sameOrigin} from '@/lib/http/origin';
import {boundedText} from '@/lib/http/body';
import {catalogAccess} from '@/lib/staff/access';
import {attendanceInput} from '@/lib/open-houses/attendance-validation';
export async function POST(request:NextRequest){
 if(!sameOrigin(request))return NextResponse.json({error:'Invalid request origin.'},{status:403});if(!request.headers.get('content-type')?.includes('application/json'))return NextResponse.json({error:'JSON required.'},{status:415});
 const {client,user,membership}=await catalogAccess(['admin','realtor','manager']);if(!user)return NextResponse.json({error:'Verified staff sign-in required.'},{status:401});if(!membership)return NextResponse.json({error:'Organization staff required.'},{status:403});
 let body;try{body=await boundedText(request,3000);}catch{return NextResponse.json({error:'Request too large.'},{status:413});}let input;try{input=attendanceInput(JSON.parse(body));}catch(error){return NextResponse.json({error:error instanceof Error?error.message:'Check attendance details.'},{status:400});}
 const {data,error}=await client.rpc('record_open_house_attendance',input);if(error){const status=error.code==='42501'?403:['40001','23505','40P01'].includes(error.code)?409:400;return NextResponse.json({error:status===403?'An event reservation in your organization is required.':status===409?'Reservation or attendance changed. Refresh before retrying.':'Attendance opens 30 minutes before the event and closes seven days after it ends. Check the party size, event state and correction reason; no-shows require an ended event.'},{status});}
 return NextResponse.json(data,{headers:{'Cache-Control':'private, no-store'}});
}
