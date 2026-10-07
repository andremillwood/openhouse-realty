import type {SupabaseClient} from '@supabase/supabase-js';
import {validId} from './catalog';
async function verified(client:SupabaseClient,owner:string){const r=await client.auth.getUser();if(r.error||r.data.user?.id!==owner||!r.data.user.email_confirmed_at||r.data.user.is_anonymous)throw new Error('Verified security account required.');}
export async function securityEntry(client:SupabaseClient,owner:string,permit:string){
 if(!validId(permit))throw new Error('Full permit reference required.');await verified(client,owner);
 const response=await client.rpc('security_entry_snapshot',{p_permit_id:permit});if(response.error||!response.data)throw new Error('Assigned permit unavailable.');const r=response.data;
 const date=(v:unknown):v is string=>typeof v==='string'&&Number.isFinite(Date.parse(v));
 if(r.permit_id!==permit||!['authorized','revoked'].includes(r.permit_state)||typeof r.entry_allowed!=='boolean'||!date(r.valid_from)||!date(r.valid_until)||Date.parse(r.valid_until)<=Date.parse(r.valid_from)||(['property_name','company_name','job_title','shared_instructions'] as const).some(k=>typeof r[k]!=='string'||!r[k].trim()||r[k].length>3000))throw new Error('Invalid permit snapshot.');
 if(r.presence_id===null){if(r.presence_state!==null||r.presence_version!==null||r.checked_in_at!==null||r.checked_out_at!==null)throw new Error('Invalid presence snapshot.');}
 else if(!validId(r.presence_id)||!['on_site','exited'].includes(r.presence_state)||!Number.isInteger(r.presence_version)||r.presence_version<1||r.presence_version>=2147483647||!date(r.checked_in_at)||(r.presence_state==='on_site'?r.checked_out_at!==null:!date(r.checked_out_at)||Date.parse(r.checked_out_at)<Date.parse(r.checked_in_at))||r.entry_allowed)throw new Error('Invalid presence snapshot.');
 if(r.entry_allowed&&r.permit_state!=='authorized')throw new Error('Invalid entry eligibility.');
 await verified(client,owner);
 return {permit:r.permit_id as string,property:r.property_name as string,company:r.company_name as string,title:r.job_title as string,instructions:r.shared_instructions as string,state:r.permit_state as string,from:r.valid_from as string,until:r.valid_until as string,entryAllowed:r.entry_allowed as boolean,presence:r.presence_id as string|null,presenceState:r.presence_state as string|null,presenceVersion:r.presence_version as number|null,arrival:r.checked_in_at as string|null,departure:r.checked_out_at as string|null};
}
