import {NextRequest,NextResponse} from 'next/server';
import {sameOrigin} from '@/lib/http/origin';
import {boundedText} from '@/lib/http/body';
import {createClient} from '@/lib/supabase/server';
import {rsvpInput} from '@/lib/open-houses/rsvp-validation';
export async function POST(request:NextRequest){
 if(!sameOrigin(request))return NextResponse.json({error:'Invalid request origin.'},{status:403});if(!request.headers.get('content-type')?.includes('application/json'))return NextResponse.json({error:'JSON required.'},{status:415});
 const client=await createClient(),{data:{user},error:authError}=await client.auth.getUser();if(authError||!user?.email_confirmed_at)return NextResponse.json({error:'Sign in with a verified email to reserve your place.'},{status:401});
 let body;try{body=await boundedText(request,2500);}catch{return NextResponse.json({error:'Request too large.'},{status:413});}let input;try{input=rsvpInput(JSON.parse(body));}catch(error){return NextResponse.json({error:error instanceof Error?error.message:'Check reservation details.'},{status:400});}
 const {data,error}=await client.rpc('reserve_open_house',input);if(error){const status=error.code==='42501'?403:['23505','40001','40P01'].includes(error.code)?409:400;return NextResponse.json({error:status===403?'This event is no longer accepting reservations, or this reservation is unavailable.':status===409?'The reservation or attendance record changed, your event times overlap, or the party would exceed capacity. Refresh and check your account; recorded attendance requires a staff correction before RSVP changes.':'Check your party size and attendance contact consent.'},{status});}
 return NextResponse.json(data,{headers:{'Cache-Control':'private, no-store'}});
}
