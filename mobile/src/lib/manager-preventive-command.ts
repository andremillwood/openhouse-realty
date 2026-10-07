import type {SupabaseClient} from '@supabase/supabase-js';
import {preventivePlanInput} from '../../../lib/staff/preventive-plan-validation';
import {managerPreventiveDetail} from './manager-preventive-detail';
import {managerAccess} from './manager-access';
import {preventiveSnapshot} from './preventive-snapshot';
import {validId} from './catalog';
import {EnquiryFailure} from './enquiries';
export type PreventiveCommand=Readonly<{action:'issue'|'skip';plan_id:string;version:number;request_id:string;reason:string;approved:true}>;
export function preventiveCommand(value:PreventiveCommand):PreventiveCommand{const r=preventivePlanInput(value);if(r.p_action!=='issue'&&r.p_action!=='skip')throw new EnquiryFailure('Scheduled decision required.',false);return Object.freeze({action:r.p_action,plan_id:r.p_plan_id!,version:r.p_expected_version,request_id:r.p_request_id,reason:r.p_reason,approved:true});}
export async function sendPreventiveCommand(client:SupabaseClient,owner:string,value:PreventiveCommand){
 let input:PreventiveCommand,access:NonNullable<Awaited<ReturnType<typeof managerAccess>>>;
 try{input=preventiveCommand(value);const membership=await managerAccess(client,owner);if(!membership||!await managerPreventiveDetail(client,owner,input.plan_id))throw Error();const latest=await managerAccess(client,owner);if(!latest||latest.organization!==membership.organization||latest.role!==membership.role||latest.revision!==membership.revision)throw Error();access=membership;}catch{throw new EnquiryFailure('Check management membership and approved decision details.',false);}
 const args=preventivePlanInput(input),skip={p_request_id:args.p_request_id,p_plan_id:args.p_plan_id,p_expected_version:args.p_expected_version,p_reason:args.p_reason,p_approved:true};
 let response;try{response=await client.rpc(input.action==='skip'?'skip_preventive_occurrence':'manage_preventive_plan',input.action==='skip'?skip:args);}catch{throw new EnquiryFailure('Decision could not be confirmed. Retry the same request.',true);}
 if(response.error)throw new EnquiryFailure('Decision could not be confirmed. Refresh or retry the same request.',!['42501','22023','22P02','40001','23505'].includes(response.error.code));
 try{const ack=response.data;if(!ack||ack.id!==input.plan_id||ack.version!==input.version+1||(input.action==='issue'?!validId(ack.work_order_id):ack.work_order_id!==null))throw Error();
 const event=await client.from('preventive_maintenance_events').select('organization_id,plan_id,actor_user_id,request_id,action,version,reason,work_order_id,snapshot').eq('organization_id',access.organization).eq('plan_id',input.plan_id).eq('actor_user_id',owner).eq('request_id',input.request_id).maybeSingle();const r=event.data;
 if(event.error||!r||r.organization_id!==access.organization||r.plan_id!==input.plan_id||r.actor_user_id!==owner||r.request_id!==input.request_id||r.action!==input.action||r.version!==ack.version||r.reason!==input.reason||r.work_order_id!==ack.work_order_id)throw Error();
 const before=preventiveSnapshot(r.snapshot?.before,input.plan_id,access.organization),after=preventiveSnapshot(r.snapshot?.after,input.plan_id,access.organization),next=new Date(before.due+'T00:00:00Z');next.setUTCDate(next.getUTCDate()+before.interval);
 if(before.version!==input.version||after.version!==ack.version||before.state!=='active'||after.state!==before.state||after.due!==next.toISOString().slice(0,10)||before.title!==after.title||before.description!==after.description||before.priority!==after.priority||before.property!==after.property||before.unit!==after.unit||before.interval!==after.interval)throw Error();
 const current=await managerPreventiveDetail(client,owner,input.plan_id),membership=await managerAccess(client,owner);if(!current||current.version<ack.version||!membership||membership.organization!==access.organization||membership.role!==access.role||membership.revision!==access.revision)throw Error();return {id:input.plan_id,action:input.action,version:ack.version as number,due:before.due,nextDue:after.due,work:ack.work_order_id as string|null,currentVersion:current.version};
 }catch{throw new EnquiryFailure('Recorded decision could not be confirmed. Retry the same request.',true);}
}
