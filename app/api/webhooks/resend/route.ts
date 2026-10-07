import {createHash} from 'node:crypto';
import {Resend} from 'resend';
import {NextRequest,NextResponse} from 'next/server';
import {boundedText} from '@/lib/http/body';
import {createAdminClient} from '@/lib/supabase/admin';
import {deliveryEventInput} from '@/lib/notifications/delivery';
export const runtime='nodejs';
export async function POST(request:NextRequest){
 const secret=process.env.RESEND_WEBHOOK_SECRET;if(!secret||!secret.startsWith('whsec_')||secret.length<20||!process.env.RESEND_API_KEY||!process.env.SUPABASE_SECRET_KEY)return NextResponse.json({error:'Webhook configuration incomplete.'},{status:503});
 if(!request.headers.get('content-type')?.includes('application/json'))return NextResponse.json({error:'JSON required.'},{status:415});
 const id=request.headers.get('svix-id')||'',timestamp=request.headers.get('svix-timestamp')||'',signature=request.headers.get('svix-signature')||'';if(!id||!timestamp||!signature)return NextResponse.json({error:'Invalid webhook signature.'},{status:401});
 let payload;try{payload=await boundedText(request,65536);}catch{return NextResponse.json({error:'Request too large.'},{status:413});}
 let event;try{event=new Resend(process.env.RESEND_API_KEY).webhooks.verify({payload,headers:{id,timestamp,signature},webhookSecret:secret});}catch{return NextResponse.json({error:'Invalid webhook signature.'},{status:401});}
 let input;try{input=deliveryEventInput(event,id,createHash('sha256').update(payload).digest('hex'));}catch{return NextResponse.json({error:'Invalid delivery event.'},{status:400});}if(!input)return NextResponse.json({accepted:true,ignored:true},{headers:{'Cache-Control':'no-store'}});
 try{const {error}=await createAdminClient().rpc('record_resend_delivery_event',input);if(error)return NextResponse.json({error:'Delivery event could not be recorded.'},{status:error.code==='22023'?400:503});return NextResponse.json({accepted:true},{headers:{'Cache-Control':'no-store'}});}catch{return NextResponse.json({error:'Delivery event unavailable.'},{status:503});}
}
