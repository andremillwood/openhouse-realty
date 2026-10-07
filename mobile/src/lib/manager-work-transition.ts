import type {SupabaseClient} from '@supabase/supabase-js';
import {workOrderInput} from '../../../lib/staff/work-order-validation';
import {managerWorkDetail} from './manager-work-detail';
import {EnquiryFailure} from './enquiries';
export type WorkTransition=Readonly<{action:'triage'|'cancel';work_order_id:string;version:number;request_id:string;priority:string|null;reason:string}>;
export function workTransition(value:WorkTransition):WorkTransition{const r=workOrderInput(value);if(!['triage','cancel'].includes(r.p_action))throw new EnquiryFailure('Management transition required.',false);return Object.freeze({action:r.p_action as WorkTransition['action'],work_order_id:r.p_work_order_id!,version:r.p_expected_version,request_id:r.p_request_id,priority:r.p_priority,reason:r.p_reason});}
export async function transitionManagerWork(client:SupabaseClient,owner:string,value:WorkTransition){
 let input:WorkTransition;try{input=workTransition(value);if(!await managerWorkDetail(client,owner,input.work_order_id))throw Error();}catch{throw new EnquiryFailure('Check management access, work revision and decision details.',false);}
 let response;try{response=await client.rpc('manage_work_order',workOrderInput(input));}catch{throw new EnquiryFailure('Decision could not be confirmed. Retry the same request.',true);}
 if(response.error)throw new EnquiryFailure('Decision could not be confirmed. Refresh the work order or retry the same request.',!['42501','22023','22P02','40001','23505'].includes(response.error.code));
 const r=response.data,state=input.action==='triage'?'triaged':'cancelled';try{if(!r||r.id!==input.work_order_id||r.version!==input.version+1||r.status!==state)throw Error();const current=await managerWorkDetail(client,owner,input.work_order_id);if(!current||current.version<r.version||current.version===r.version&&(current.state!==state||input.action==='triage'&&current.priority!==input.priority))throw Error();return {id:r.id as string,state,version:r.version as number,currentState:current.state,currentVersion:current.version};}catch{throw new EnquiryFailure('Recorded decision could not be confirmed. Retry the same request.',true);}
}
