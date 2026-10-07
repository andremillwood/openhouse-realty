import type {SupabaseClient} from '@supabase/supabase-js';
import {securityAssignmentInput} from '../../../lib/staff/security-assignment-validation';
import {managerSecurityAssignment} from './manager-security-assignment';
import {managerLocation} from './manager-locations';
import {validId} from './catalog';
import {managerAccess} from './manager-access';
import {EnquiryFailure} from './enquiries';
export type SecurityCreation=Readonly<{assignment_id:null;property_id:string;email:string;version:0;request_id:string;is_active:true;reason:string;approved:true}>;
export function securityCreation(value:SecurityCreation):SecurityCreation{const r=securityAssignmentInput(value);if(r.p_assignment_id!==null||r.p_expected_version!==0||!r.p_property_id||!r.p_email||!r.p_is_active)throw new EnquiryFailure('New active assignment required.',false);return Object.freeze({assignment_id:null,property_id:r.p_property_id,email:r.p_email,version:0,request_id:r.p_request_id,is_active:true,reason:r.p_reason,approved:true});}
export async function sendSecurityCreation(client:SupabaseClient,owner:string,value:SecurityCreation){
 let input:SecurityCreation,access:NonNullable<Awaited<ReturnType<typeof managerAccess>>>;
 try{input=securityCreation(value);const membership=await managerAccess(client,owner),assignment=await managerLocation(client,owner,input.property_id,null);if(!membership||!assignment)throw Error();const latest=await managerAccess(client,owner);if(!latest||latest.organization!==membership.organization||latest.role!==membership.role||latest.revision!==membership.revision)throw Error();access=membership;}catch{throw new EnquiryFailure('Check current management access and approved assignment decision.',false);}
 let response;try{response=await client.rpc('author_property_security_assignment',securityAssignmentInput(input));}catch{throw new EnquiryFailure('Assignment decision could not be confirmed. Retry the same request.',true);}
 if(response.error)throw new EnquiryFailure('Assignment decision could not be confirmed. Check current access or retry the same request.',!['42501','22023','22P02','40001','23505'].includes(response.error.code));
 try{const ack=response.data;if(!ack||!validId(ack.id)||ack.version!==input.version+1)throw Error();const event=await client.from('property_security_assignment_changes').select('organization_id,assignment_id,actor_user_id,request_id,previous_active,new_active,version,reason').eq('organization_id',access.organization).eq('assignment_id',ack.id).eq('actor_user_id',owner).eq('request_id',input.request_id).maybeSingle(),r=event.data;
 if(event.error||!r||r.organization_id!==access.organization||r.assignment_id!==ack.id||r.actor_user_id!==owner||r.request_id!==input.request_id||r.previous_active!==null||r.new_active!==input.is_active||r.version!==ack.version||r.reason!==input.reason)throw Error();const current=await managerSecurityAssignment(client,owner,ack.id),membership=await managerAccess(client,owner);
 if(!current||current.version<ack.version||current.version===ack.version&&current.active!==input.is_active||current.property.property!==input.property_id||!membership||membership.organization!==access.organization||membership.role!==access.role||membership.revision!==access.revision)throw Error();return {id:ack.id as string,active:input.is_active,version:ack.version as number,currentActive:current.active,currentVersion:current.version};
 }catch{throw new EnquiryFailure('Recorded assignment decision could not be confirmed. Retry the same request.',true);}
}
