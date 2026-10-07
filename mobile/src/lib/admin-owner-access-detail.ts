import type {SupabaseClient} from '@supabase/supabase-js';
import {managerAccess} from './manager-access';
import {managerLocation} from './manager-locations';
import {validId} from './catalog';
export async function adminOwnerAccessDetail(client:SupabaseClient,owner:string,id:string){
 if(!validId(id))throw new Error('Owner access reference required.');const access=await managerAccess(client,owner);if(!access||access.role!=='admin')throw new Error('Approved management membership required.');
 const response=await client.from('owner_property_access').select('id,organization_id,property_id,user_id,is_active,version,created_at').eq('id',id).eq('organization_id',access.organization).maybeSingle(),r=response.data;if(response.error)throw new Error('Owner access unavailable.');
 async function recheck(){const current=await managerAccess(client,owner);if(!current||current.organization!==access!.organization||current.role!==access!.role||current.revision!==access!.revision)throw new Error('Management access changed.');}
 if(!r){await recheck();return null;}
 if(r.id!==id||r.organization_id!==access.organization||!validId(r.property_id)||!validId(r.user_id)||typeof r.is_active!=='boolean'||!Number.isInteger(r.version)||r.version<1||r.version>=2147483647||typeof r.created_at!=='string'||!Number.isFinite(Date.parse(r.created_at)))throw new Error('Invalid owner access.');const location=await managerLocation(client,owner,r.property_id,null);await recheck();return {id:r.id as string,user:r.user_id as string,active:r.is_active as boolean,version:r.version as number,created:r.created_at as string,property:location};
}
