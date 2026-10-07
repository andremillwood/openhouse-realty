import type {SupabaseClient} from '@supabase/supabase-js';
import {visitInput} from '../../../lib/staff/visit-validation';
import {managerAccess} from './manager-access';
import {managerWorkDetail} from './manager-work-detail';
import {validId} from './catalog';
import {EnquiryFailure} from './enquiries';
export type ManagerVisitCommand=Readonly<{work:string;offer_id:string;request_id:string;reason:string}&({action:'propose';visit_id:null;version:0;offer_version:number;starts_at:string;ends_at:string;shared_note:string;approved:true}|{action:'cancel';visit_id:string;version:number})>;
export function managerVisitCommand(value:ManagerVisitCommand):ManagerVisitCommand{
 if(!validId(value.work)||!validId(value.offer_id))throw Error('Approved work and assignment required.');
 const normalized=visitInput(value.action==='cancel'?{...value,offer_id:null}:value);
 if(value.action==='cancel')return Object.freeze({work:value.work,offer_id:value.offer_id,action:'cancel',visit_id:normalized.p_visit_id!,version:normalized.p_expected_version,request_id:normalized.p_request_id,reason:normalized.p_reason});
 if(normalized.p_action!=='propose')throw Error('Management appointment action required.');
 return Object.freeze({work:value.work,offer_id:value.offer_id,action:'propose',visit_id:null,version:0,offer_version:normalized.p_expected_offer_version!,starts_at:normalized.p_starts_at!,ends_at:normalized.p_ends_at!,shared_note:normalized.p_shared_note!,approved:true,request_id:normalized.p_request_id,reason:normalized.p_reason});
}
async function scope(client:SupabaseClient,owner:string,input:ManagerVisitCommand,visitId?:string){
 const access=await managerAccess(client,owner),work=await managerWorkDetail(client,owner,input.work);if(!access||!work)throw Error();
 const offer=await client.from('contractor_work_offers').select('id,organization_id,work_order_id').eq('id',input.offer_id).eq('organization_id',access.organization).eq('work_order_id',input.work).maybeSingle();
 if(offer.error||!offer.data||offer.data.id!==input.offer_id||offer.data.organization_id!==access.organization||offer.data.work_order_id!==input.work)throw Error();
 let visit:null|{state:string;version:number}=null;
 if(visitId){const response=await client.from('contractor_visits').select('id,organization_id,offer_id,property_id,unit_id,state,version,starts_at,ends_at,shared_note').eq('id',visitId).eq('organization_id',access.organization).eq('offer_id',input.offer_id).eq('property_id',work.propertyId).maybeSingle();const r=response.data;
 if(response.error||!r||r.id!==visitId||r.organization_id!==access.organization||r.offer_id!==input.offer_id||r.property_id!==work.propertyId||r.unit_id!==work.unit||!['proposed','confirmed','declined','cancelled','completed'].includes(r.state)||!Number.isInteger(r.version)||r.version<1||r.version>=2147483647)throw Error();
 if(input.action==='propose'&&(Date.parse(r.starts_at)!==Date.parse(input.starts_at)||Date.parse(r.ends_at)!==Date.parse(input.ends_at)||r.shared_note!==input.shared_note))throw Error();
 visit={state:r.state,version:r.version};}
 const current=await managerAccess(client,owner);if(!current||current.organization!==access.organization||current.role!==access.role||current.revision!==access.revision)throw Error();return visit;
}
export async function submitManagerVisit(client:SupabaseClient,owner:string,value:ManagerVisitCommand){
 let input:ManagerVisitCommand;try{input=managerVisitCommand(value);await scope(client,owner,input,input.action==='cancel'?input.visit_id:undefined);}catch{throw new EnquiryFailure('Refresh approved work and appointment access.',false);}
 let response;try{response=await client.rpc('manage_contractor_visit',visitInput(input.action==='cancel'?{...input,offer_id:null}:input));}catch{throw new EnquiryFailure('Appointment decision could not be confirmed. Retry the same request.',true);}
 if(response.error)throw new EnquiryFailure('Appointment decision could not be confirmed. Refresh or retry the same request.',!['42501','22023','22P02','40001','23505'].includes(response.error.code));
 try{const r=response.data,expected=input.action==='propose'?'proposed':'cancelled';if(!r||!validId(r.id)||input.action==='cancel'&&r.id!==input.visit_id||r.state!==expected||r.version!==input.version+1)throw Error();const current=await scope(client,owner,input,r.id);if(!current||current.version<r.version||current.version===r.version&&current.state!==r.state)throw Error();return {id:r.id as string,state:expected,version:r.version as number,currentState:current.state,currentVersion:current.version};}catch{throw new EnquiryFailure('Recorded appointment decision could not be confirmed. Retry the same request.',true);}
}
