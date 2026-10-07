import type {SupabaseClient} from '@supabase/supabase-js';
import {managerAccess} from './manager-access';
import {managerLocation} from './manager-locations';
import {validId} from './catalog';
export async function managerSecurityAssignments(client:SupabaseClient,owner:string,property:string,pageInput:number){
 const access=await managerAccess(client,owner);if(!access)throw new Error('Approved manager membership required.');
 const location=await managerLocation(client,owner,property,null);const query=(head=false)=>{return client.from('property_security_assignments').select('id,organization_id,property_id,user_id,is_active,version,created_at',{head,count:'exact'}).eq('organization_id',access.organization).eq('property_id',property);};
 const count=await query(true);if(count.error||!Number.isSafeInteger(count.count)||count.count!<0)throw new Error('Security register unavailable.');const total=count.count!,pages=Math.max(1,Math.ceil(total/25)),page=Math.min(Math.max(1,Number.isSafeInteger(pageInput)?pageInput:1),pages);
 const response=total?await query().order('created_at',{ascending:false}).order('id',{ascending:true}).range((page-1)*25,page*25-1):{data:[],error:null};if(response.error||!Array.isArray(response.data)||response.data.length>25)throw new Error('Security register unavailable.');
 const rows=response.data.map(r=>{if(!validId(r.id)||r.organization_id!==access.organization||r.property_id!==property||!validId(r.user_id)||typeof r.is_active!=='boolean'||!Number.isInteger(r.version)||r.version<1||r.version>=2147483647||typeof r.created_at!=='string'||!Number.isFinite(Date.parse(r.created_at)))throw new Error('Invalid security assignment.');return {id:r.id as string,user:r.user_id as string,active:r.is_active as boolean,version:r.version as number,created:r.created_at as string};});if(new Set(rows.map(r=>r.id)).size!==rows.length||new Set(rows.map(r=>r.user)).size!==rows.length)throw new Error('Duplicate security assignments.');
 const current=await managerAccess(client,owner);if(!current||current.organization!==access.organization||current.role!==access.role||current.revision!==access.revision)throw new Error('Management access changed.');const latest=await managerLocation(client,owner,property,null);if(latest.name!==location.name)throw new Error('Managed property changed.');return {total,pages,page,rows,property:location};
}
