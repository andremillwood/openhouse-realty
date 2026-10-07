import type {SupabaseClient} from '@supabase/supabase-js';
import {managerAccess} from './manager-access';
import {workState} from './manager-work';
import {validId} from './catalog';
export async function managerWorkDetail(client:SupabaseClient,owner:string,id:string){
 if(!validId(id))throw new Error('Work reference required.');const access=await managerAccess(client,owner);if(!access)throw new Error('Approved management membership required.');
 const response=await client.from('work_orders').select('id,organization_id,title,description,priority,status,revision,property_id,unit_id,reported_by,created_at').eq('id',id).eq('organization_id',access.organization).maybeSingle();const r=response.data;if(response.error)throw new Error('Work order unavailable.');
 async function recheck(){const current=await managerAccess(client,owner);if(!current||current.organization!==access!.organization||current.role!==access!.role||current.revision!==access!.revision)throw new Error('Management access changed.');}
 if(!r){await recheck();return null;}
 if(r.id!==id||r.organization_id!==access.organization||!validId(r.property_id)||r.unit_id!==null&&!validId(r.unit_id)||r.reported_by!==null&&!validId(r.reported_by)||typeof r.title!=='string'||!r.title.trim()||r.title.length>500||typeof r.description!=='string'||!r.description.trim()||r.description.length>5000||!workState(r.status)||!['low','standard','high','urgent'].includes(r.priority)||!Number.isInteger(r.revision)||r.revision<0||r.revision>=2147483647||typeof r.created_at!=='string'||!Number.isFinite(Date.parse(r.created_at)))throw new Error('Invalid work order.');
 const property=await client.from('properties').select('id,organization_id,name').eq('id',r.property_id).eq('organization_id',access.organization).maybeSingle();const p=property.data;if(property.error||!p||p.id!==r.property_id||p.organization_id!==access.organization||typeof p.name!=='string'||!p.name.trim()||p.name.length>500)throw new Error('Work property unavailable.');
 if(r.unit_id){const unit=await client.from('units').select('id,property_id').eq('id',r.unit_id).eq('property_id',r.property_id).maybeSingle();if(unit.error||!unit.data||unit.data.id!==r.unit_id||unit.data.property_id!==r.property_id)throw new Error('Work unit unavailable.');}
 await recheck();return {id:r.id as string,title:r.title as string,description:r.description as string,state:r.status as string,priority:r.priority as string,version:r.revision as number,property:p.name as string,propertyId:r.property_id as string,unit:r.unit_id as string|null,reporter:r.reported_by as string|null,created:r.created_at as string};
}
