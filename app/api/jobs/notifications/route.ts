import { timingSafeEqual } from 'node:crypto';
import { NextRequest, NextResponse } from 'next/server';
import { createAdminClient } from '@/lib/supabase/admin';
import { sendTransactionalEmail } from '@/lib/email';
import {maintenanceNotice} from '@/lib/notifications/maintenance';
import {notificationOrigin} from '@/lib/notifications/origin';
export const runtime='nodejs';
export const maxDuration=60;
export async function GET(request:NextRequest){
 const secret=process.env.CRON_SECRET;const authorization=Buffer.from(request.headers.get('authorization')||'');const expected=Buffer.from(`Bearer ${secret}`);
 if(!secret||secret.length<32||authorization.length!==expected.length||!timingSafeEqual(authorization,expected))return NextResponse.json({error:'Unauthorized'},{status:401});
 const appOrigin=notificationOrigin(process.env.NEXT_PUBLIC_APP_URL);
 if(!appOrigin||!process.env.RESEND_API_KEY||!process.env.RESEND_FROM_EMAIL||!process.env.ENQUIRY_TO_EMAIL||!process.env.SUPABASE_SECRET_KEY)return NextResponse.json({error:'Notification worker configuration incomplete.'},{status:503});
 try{
 const client=createAdminClient();
 const {data:events,error:preparationError}=await client.rpc('pending_maintenance_notifications');
 if(preparationError)throw new Error('Maintenance preparation unavailable');
 for(const event of events||[]){
  const notice=maintenanceNotice(event.kind,event.reference);
  const {error:queueError}=await client.rpc('queue_maintenance_notification',{p_event_id:event.event_id,p_subject:notice.subject,p_text:notice.text});
  if(queueError)throw new Error('Maintenance queue unavailable');
 }
 const {data:jobs,error}=await client.rpc('claim_transactional_notifications',{p_sender:process.env.RESEND_FROM_EMAIL,p_recipient:process.env.ENQUIRY_TO_EMAIL,p_app_origin:appOrigin});if(error)throw new Error('Claim failed');
 let accepted=0,failed=0,uncertain=0,skipped=0;
 const outcomes=await Promise.allSettled((jobs||[]).map(async(job:{outbox_id:string;enquiry_id:string|null;lease_token:string;contact_name:string;contact_email:string;phone:string;message:string;target_title:string;sender:string;recipient:string;subject_snapshot:string|null;text_snapshot:string|null})=>{
  let providerId:string|null=null;let success=false;
  const {data:current,error:currentError}=await client.rpc('notification_attempt_current',{p_id:job.outbox_id,p_lease_token:job.lease_token});
  if(currentError){uncertain++;return;}if(!current){skipped++;return;}
  try{const result=await sendTransactionalEmail({from:job.sender,to:job.recipient,subject:(job.subject_snapshot || `New enquiry: ${job.target_title}`).replace(/[\r\n]/g,' ').slice(0,180),text:job.text_snapshot || `New Open House enquiry\n\nReference: ${job.enquiry_id}\nProperty or realtor: ${job.target_title}\nName: ${job.contact_name}\nEmail: ${job.contact_email}\nPhone: ${job.phone||'Not supplied'}\n\n${job.message}\n\nReview this enquiry in the staff inbox.`,idempotencyKey:`enquiry-${job.outbox_id}`});providerId=result.id;success=true;}catch{failed++;}
  const {data:completed,error:completeError}=await client.rpc('complete_enquiry_notification',{p_id:job.outbox_id,p_lease_token:job.lease_token,p_provider_id:providerId,p_success:success});
  if(completeError||!completed)uncertain++;else if(success)accepted++;
 }));
 uncertain+=outcomes.filter(result=>result.status==='rejected').length;
 const {error:reconciliationError}=await client.rpc('reconcile_resend_delivery_events');if(reconciliationError)uncertain++;
 return NextResponse.json({claimed:jobs?.length||0,accepted,failed,uncertain,skipped},{status:uncertain?503:200,headers:{'Cache-Control':'no-store'}});
 }catch{return NextResponse.json({error:'Notification worker unavailable.'},{status:503});}
}
