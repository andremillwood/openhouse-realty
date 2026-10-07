import type {SupabaseClient} from '@supabase/supabase-js';
import {entryPermitInput} from '../../../lib/staff/entry-permit-validation';
import {managerAccess} from './manager-access';
import {managerWorkDetail} from './manager-work-detail';
import {validId} from './catalog';
import {EnquiryFailure} from './enquiries';
export type ManagerEntryCommand=Readonly<{work:string;offer_id:string;visit_id:string;request_id:string;reason:string}&({action:'authorize';permit_id:null;version:0;visit_version:number;valid_from:string;valid_until:string;shared_instructions:string;approved:true}|{action:'revoke';permit_id:string;version:number})>;
const rpcInput=(value:ManagerEntryCommand)=>entryPermitInput(value.action==='revoke'?{...value,visit_id:null}:value);
export function managerEntryCommand(value:ManagerEntryCommand):ManagerEntryCommand{
 if(!validId(value.work)||!validId(value.offer_id)||!validId(value.visit_id))throw Error('Approved work and appointment required.');const r=rpcInput(value);
 if(value.action==='revoke')return Object.freeze({work:value.work,offer_id:value.offer_id,visit_id:value.visit_id,action:'revoke',permit_id:r.p_permit_id!,version:r.p_expected_version,request_id:r.p_request_id,reason:r.p_reason});
 if(r.p_action!=='authorize')throw Error('Management entry action required.');return Object.freeze({work:value.work,offer_id:value.offer_id,visit_id:value.visit_id,action:'authorize',permit_id:null,version:0,visit_version:r.p_expected_visit_version!,valid_from:r.p_valid_from!,valid_until:r.p_valid_until!,shared_instructions:r.p_shared_instructions!,approved:true,request_id:r.p_request_id,reason:r.p_reason});
}
async function scope(client:SupabaseClient,owner:string,input:ManagerEntryCommand,permitId?:string){
 const access=await managerAccess(client,owner),work=await managerWorkDetail(client,owner,input.work);if(!access||!work)throw Error();
 const offer=await client.from('contractor_work_offers').select('id,organization_id,work_order_id').eq('id',input.offer_id).eq('organization_id',access.organization).eq('work_order_id',input.work).maybeSingle();
 if(offer.error||!offer.data||offer.data.id!==input.offer_id||offer.data.organization_id!==access.organization||offer.data.work_order_id!==input.work)throw Error();
 let visit:null|{state:string;version:number}=null;
 {const response=await client.from('contractor_visits').select('id,organization_id,offer_id,property_id,unit_id,state,version,starts_at,ends_at,shared_note').eq('id',input.visit_id).eq('organization_id',access.organization).eq('offer_id',input.offer_id).eq('property_id',work.propertyId).maybeSingle();const r=response.data;
 if(response.error||!r||r.id!==input.visit_id||r.organization_id!==access.organization||r.offer_id!==input.offer_id||r.property_id!==work.propertyId||r.unit_id!==work.unit||!['proposed','confirmed','declined','cancelled','completed'].includes(r.state)||!Number.isInteger(r.version)||r.version<1||r.version>=2147483647)throw Error();
 if(permitId){const permit=await client.from('contractor_entry_permits').select('id,organization_id,visit_id,state,version,valid_from,valid_until,shared_instructions').eq('id',permitId).eq('organization_id',access.organization).eq('visit_id',input.visit_id).maybeSingle();const p=permit.data;if(permit.error||!p||p.id!==permitId||p.organization_id!==access.organization||p.visit_id!==input.visit_id||!['authorized','revoked'].includes(p.state)||!Number.isInteger(p.version)||p.version<1||p.version>=2147483647)throw Error();if(input.action==='authorize'&&(Date.parse(p.valid_from)!==Date.parse(input.valid_from)||Date.parse(p.valid_until)!==Date.parse(input.valid_until)||p.shared_instructions!==input.shared_instructions))throw Error();visit={state:p.state,version:p.version};}}
 const current=await managerAccess(client,owner);if(!current||current.organization!==access.organization||current.role!==access.role||current.revision!==access.revision)throw Error();return visit;
}
export async function submitManagerEntry(client:SupabaseClient,owner:string,value:ManagerEntryCommand){
 let input:ManagerEntryCommand;try{input=managerEntryCommand(value);await scope(client,owner,input,input.action==='revoke'?input.permit_id:undefined);}catch{throw new EnquiryFailure('Refresh approved work and entry access.',false);}
 let response;try{response=await client.rpc('manage_entry_permit',rpcInput(input));}catch{throw new EnquiryFailure('Entry decision could not be confirmed. Retry the same request.',true);}
 if(response.error)throw new EnquiryFailure('Entry decision could not be confirmed. Refresh or retry the same request.',!['42501','22023','22P02','40001','23505'].includes(response.error.code));
 try{const r=response.data,expected=input.action==='authorize'?'authorized':'revoked';if(!r||!validId(r.id)||input.action==='revoke'&&r.id!==input.permit_id||r.state!==expected||r.version!==input.version+1)throw Error();const current=await scope(client,owner,input,r.id);if(!current||current.version<r.version||current.version===r.version&&current.state!==r.state)throw Error();return {id:r.id as string,state:expected,version:r.version as number,currentState:current.state,currentVersion:current.version};}catch{throw new EnquiryFailure('Recorded entry decision could not be confirmed. Retry the same request.',true);}
}
