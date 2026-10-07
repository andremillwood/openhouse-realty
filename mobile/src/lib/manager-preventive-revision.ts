import type {SupabaseClient} from '@supabase/supabase-js';
import {preventivePlanInput} from '../../../lib/staff/preventive-plan-validation';
import {managerPreventiveDetail} from './manager-preventive-detail';
import {managerAccess} from './manager-access';
import {preventiveSnapshot} from './preventive-snapshot';
import {EnquiryFailure} from './enquiries';
export type PreventiveRevision=Readonly<{action:'revise';title:string;description:string;priority:string;interval_days:number;next_due_on:string;state:string;plan_id:string;version:number;request_id:string;reason:string;approved:true}>;
export function preventiveRevision(value:PreventiveRevision):PreventiveRevision{const r=preventivePlanInput(value);if(r.p_action!=='revise')throw new EnquiryFailure('Plan revision required.',false);return Object.freeze({title:r.p_title!,description:r.p_description!,priority:r.p_priority!,interval_days:r.p_interval_days!,next_due_on:r.p_next_due_on!,state:r.p_state!,action:'revise',plan_id:r.p_plan_id!,version:r.p_expected_version,request_id:r.p_request_id,reason:r.p_reason,approved:true});}
export async function sendPreventiveRevision(client:SupabaseClient,owner:string,value:PreventiveRevision){
 let input:PreventiveRevision,access:NonNullable<Awaited<ReturnType<typeof managerAccess>>>;
 try{input=preventiveRevision(value);const membership=await managerAccess(client,owner);if(!membership||!await managerPreventiveDetail(client,owner,input.plan_id))throw Error();const latest=await managerAccess(client,owner);if(!latest||latest.organization!==membership.organization||latest.role!==membership.role||latest.revision!==membership.revision)throw Error();access=membership;}catch{throw new EnquiryFailure('Check management membership and approved decision details.',false);}
 const args=preventivePlanInput(input);let response;try{response=await client.rpc('manage_preventive_plan',args);}catch{throw new EnquiryFailure('Decision could not be confirmed. Retry the same request.',true);}
 if(response.error)throw new EnquiryFailure('Decision could not be confirmed. Refresh or retry the same request.',!['42501','22023','22P02','40001','23505'].includes(response.error.code));
 try{const ack=response.data;if(!ack||ack.id!==input.plan_id||ack.version!==input.version+1||ack.work_order_id!==null)throw Error();
 const event=await client.from('preventive_maintenance_events').select('organization_id,plan_id,actor_user_id,request_id,action,version,reason,work_order_id,snapshot').eq('organization_id',access.organization).eq('plan_id',input.plan_id).eq('actor_user_id',owner).eq('request_id',input.request_id).maybeSingle();const r=event.data;
 if(event.error||!r||r.organization_id!==access.organization||r.plan_id!==input.plan_id||r.actor_user_id!==owner||r.request_id!==input.request_id||r.action!==input.action||r.version!==ack.version||r.reason!==input.reason||r.work_order_id!==ack.work_order_id)throw Error();
 const before=preventiveSnapshot(r.snapshot?.before,input.plan_id,access.organization),after=preventiveSnapshot(r.snapshot?.after,input.plan_id,access.organization);
 if(before.version!==input.version||after.version!==ack.version||before.state==='retired'||before.property!==after.property||before.unit!==after.unit||after.title!==input.title||after.description!==input.description||after.priority!==input.priority||after.state!==input.state||after.interval!==input.interval_days||after.due!==input.next_due_on)throw Error();
 const current=await managerPreventiveDetail(client,owner,input.plan_id),membership=await managerAccess(client,owner);if(!current||current.version<ack.version||!membership||membership.organization!==access.organization||membership.role!==access.role||membership.revision!==access.revision)throw Error();return {id:input.plan_id,action:input.action,version:ack.version as number,due:before.due,nextDue:after.due,work:ack.work_order_id as string|null,currentVersion:current.version};
 }catch{throw new EnquiryFailure('Recorded decision could not be confirmed. Retry the same request.',true);}
}
