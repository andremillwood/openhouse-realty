import {uuidPattern} from '@/lib/enquiries/validation';
export const deliveryEvents=['email.sent','email.delivered','email.delivery_delayed','email.bounced','email.complained','email.failed','email.suppressed'] as const;
/** Run only after cryptographic verification of the original request bytes. */
export function deliveryEventInput(value:unknown,eventId:string,hash:string){
 if(!value||typeof value!=='object'||Array.isArray(value))throw new Error('Invalid event.');const event=value as Record<string,unknown>;
 if(typeof event.type!=='string')throw new Error('Invalid event type.');if(!deliveryEvents.includes(event.type as typeof deliveryEvents[number]))return null;
 const data=event.data;if(!data||typeof data!=='object'||Array.isArray(data)||typeof (data as Record<string,unknown>).email_id!=='string'||!uuidPattern.test((data as Record<string,string>).email_id)||typeof event.created_at!=='string'||!/^\d{4}-\d{2}-\d{2}T/.test(event.created_at)||!Number.isFinite(Date.parse(event.created_at))||!/^[A-Za-z0-9_-]{1,200}$/.test(eventId)||!/^[a-f0-9]{64}$/.test(hash))throw new Error('Invalid verified event data.');
 return {p_event_id:eventId,p_provider_id:(data as Record<string,string>).email_id,p_event_type:event.type,p_occurred_at:new Date(event.created_at).toISOString(),p_payload_sha256:hash};
}
