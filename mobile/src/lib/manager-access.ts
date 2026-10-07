import type {SupabaseClient} from '@supabase/supabase-js';
import {validId} from './catalog';
async function verified(client:SupabaseClient,owner:string){const r=await client.auth.getUser();if(r.error||r.data.user?.id!==owner||!r.data.user.email_confirmed_at||r.data.user.is_anonymous)throw new Error('Verified management account required.');}
export async function managerAccess(client:SupabaseClient,owner:string){
 await verified(client,owner);const response=await client.from('staff_accounts').select('user_id,organization_id,role,membership_revision').eq('user_id',owner).maybeSingle();if(response.error)throw new Error('Management access unavailable.');const r=response.data;if(!r){await verified(client,owner);return null;}
 if(r.user_id!==owner||!validId(r.organization_id)||!validId(r.membership_revision)||!['admin','manager','realtor','finance'].includes(r.role))throw new Error('Invalid staff membership.');await verified(client,owner);
 if(!['admin','manager'].includes(r.role))return null;return {organization:r.organization_id as string,role:r.role as 'admin'|'manager',revision:r.membership_revision as string};
}
