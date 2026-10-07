import type {SupabaseClient} from '@supabase/supabase-js';
import {presenceInput} from '../../../lib/security/presence-validation';
import {securityEntry} from './security-entry';
import {validId} from './catalog';
import {EnquiryFailure} from './enquiries';
export type PresenceAttempt=Readonly<{permit:string;action:'check_in'|'check_out';permit_id:string|null;presence_id:string|null;version:number;identity_checked:true|null;reason:string;request_id:string}>;
export function presenceAttempt(value:PresenceAttempt):PresenceAttempt{if(!validId(value.permit))throw new EnquiryFailure('Permit reference required.',false);const r=presenceInput(value);if(r.p_action==='check_in'&&r.p_permit_id!==value.permit)throw new EnquiryFailure('Arrival permit must match.',false);return Object.freeze({permit:value.permit,action:r.p_action as PresenceAttempt['action'],permit_id:r.p_permit_id,presence_id:r.p_presence_id,version:r.p_expected_version,identity_checked:r.p_identity_checked as true|null,reason:r.p_reason,request_id:r.p_request_id});}
export async function recordSecurityPresence(client:SupabaseClient,owner:string,value:PresenceAttempt){
 let input:PresenceAttempt;try{input=presenceAttempt(value);const before=await securityEntry(client,owner,input.permit);if(input.action==='check_out'&&before.presence!==input.presence_id)throw Error();}catch{throw new EnquiryFailure('Check the permit, identity confirmation and presence details.',false);}
 let response;try{response=await client.rpc('record_contractor_presence',presenceInput(input));}catch{throw new EnquiryFailure('Presence could not be confirmed. Retry the same request.',true);}
 if(response.error)throw new EnquiryFailure('Presence could not be confirmed. Refresh the permit or retry the same request.',!['42501','22023','22P02','40001','23505'].includes(response.error.code));
 const r=response.data,expected=input.action==='check_in'?'on_site':'exited';try{if(!r||!validId(r.id)||r.state!==expected||r.version!==input.version+1||input.action==='check_out'&&r.id!==input.presence_id)throw Error();const current=await securityEntry(client,owner,input.permit);if(current.presence!==r.id||current.presenceVersion===null||current.presenceVersion<r.version||current.presenceVersion===r.version&&current.presenceState!==r.state)throw Error();return {id:r.id as string,state:expected,version:r.version as number,currentState:current.presenceState,currentVersion:current.presenceVersion};}catch{throw new EnquiryFailure('Recorded presence could not be confirmed. Retry the same request.',true);}
}
