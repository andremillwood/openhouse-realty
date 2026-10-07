import type {SupabaseClient} from '@supabase/supabase-js';
import {managerAccess} from './manager-access';
import {validId} from './catalog';
import {invitationRecord} from './admin-invitations';
export async function adminInvitationDetail(client:SupabaseClient,owner:string,id:string){
 if(!validId(id))throw Error('Invitation reference required.');const access=await managerAccess(client,owner);if(!access||access.role!=='admin')throw Error('Administrator membership required.');const response=await client.from('staff_invitations').select('id,organization_id,invite_email,role,state,version,expires_at,created_at').eq('id',id).eq('organization_id',access.organization).maybeSingle();if(response.error||response.data&&response.data.id!==id)throw Error('Invitation unavailable.');const record=response.data?invitationRecord(response.data,access.organization):null;const current=await managerAccess(client,owner);if(!current||current.organization!==access.organization||current.role!==access.role||current.revision!==access.revision)throw Error('Administrator membership changed.');return record;
}
