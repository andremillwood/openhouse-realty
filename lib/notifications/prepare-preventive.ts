import {preventiveNotice} from './preventive';
type Client={rpc(name:string,args?:Record<string,unknown>):PromiseLike<{data:unknown;error:unknown}>};
/** Preparation only: this function never sends email or claims delivery jobs. */
export async function preparePreventiveNotifications(client:Client){
 const {data,error}=await client.rpc('pending_preventive_notifications');
 if(error||!Array.isArray(data)||data.length>20)throw new Error('Preventive preparation unavailable.');
 // Validate the entire bounded batch before queueing any member.
 const uuid=/^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
 const notices=data.map(event=>{
  if(!event||typeof event.event_id!=='string'||!uuid.test(event.event_id))throw new Error('Invalid preventive event reference.');
  return {id:event.event_id,notice:preventiveNotice(event.kind,event.plan_id,event.work_order_id??null)};
 });
 let queued=0,superseded=0;
 for(const {id,notice} of notices){
  const result=await client.rpc('queue_preventive_notification',{p_event_id:id,p_subject:notice.subject,p_text:notice.text});
  if(result.error||(result.data!==null&&(typeof result.data!=='string'||!uuid.test(result.data))))throw new Error('Preventive queue result unavailable.');
  if(result.data===null)superseded++;else queued++;
 }
 return {queued,superseded};
}
