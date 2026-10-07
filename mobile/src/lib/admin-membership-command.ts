import type {SupabaseClient} from '@supabase/supabase-js';
import {membershipInput} from '../../../lib/staff/membership-validation';
import {managerAccess} from './manager-access';
import {validId} from './catalog';
import {EnquiryFailure} from './enquiries';
export type MembershipCommand=Readonly<{email:string;role:string|null;revision:string|null;request_id:string;reason:string;approved:true}>;
export function membershipCommand(value:MembershipCommand):MembershipCommand{const r=membershipInput(value);if(r.p_role===null&&r.p_expected_revision===null)throw new EnquiryFailure('Current membership required for revocation.',false);return Object.freeze({email:r.p_email,role:r.p_role,revision:r.p_expected_revision,request_id:r.p_request_id,reason:r.p_reason,approved:true});}
export async function sendMembershipCommand(client:SupabaseClient,owner:string,value:MembershipCommand){
 let input:MembershipCommand,access:NonNullable<Awaited<ReturnType<typeof managerAccess>>>;try{input=membershipCommand(value);const current=await managerAccess(client,owner);if(!current||current.role!=='admin')throw Error();access=current;}catch{throw new EnquiryFailure('Check administrator membership and approved role change.',false);}
 let response;try{response=await client.rpc('manage_staff_membership',membershipInput(input));}catch{throw new EnquiryFailure('Staff change could not be confirmed. Retry the same request.',true);}
 if(response.error)throw new EnquiryFailure('Staff change could not be confirmed. Refresh or retry the same request.',!['42501','22023','22P02','40001','23505'].includes(response.error.code));
 try{const ack=response.data;if(!ack||!validId(ack.user_id)||ack.role!==input.role||(input.role===null?ack.revision!==null:!validId(ack.revision)))throw Error();const event=await client.from('staff_membership_changes').select('organization_id,actor_user_id,target_user_id,target_email,request_id,previous_role,new_role,previous_revision,new_revision,reason').eq('organization_id',access.organization).eq('actor_user_id',owner).eq('request_id',input.request_id).maybeSingle(),r=event.data;
 if(event.error||!r||r.organization_id!==access.organization||r.actor_user_id!==owner||r.target_user_id!==ack.user_id||r.target_email!==input.email||r.request_id!==input.request_id||r.new_role!==input.role||r.previous_revision!==input.revision||r.new_revision!==ack.revision||r.reason!==input.reason||(input.revision===null?r.previous_role!==null:!['admin','manager','realtor','finance'].includes(r.previous_role)))throw Error();
 const current=await managerAccess(client,owner);if(!current||current.organization!==access.organization||current.role!=='admin'||(ack.user_id===owner?current.revision!==ack.revision:current.revision!==access.revision))throw Error();return {user:ack.user_id as string,role:input.role,revision:ack.revision as string|null};
 }catch{throw new EnquiryFailure('Recorded membership decision could not be confirmed. Another administrator may need to review history if your own access changed.',true);}
}
