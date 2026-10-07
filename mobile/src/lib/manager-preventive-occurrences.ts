import type {SupabaseClient} from '@supabase/supabase-js';
import {managerPreventiveDetail} from './manager-preventive-detail';
import {managerAccess} from './manager-access';
import {preventiveSnapshot} from './preventive-snapshot';
import {validId} from './catalog';
export async function managerPreventiveOccurrences(client:SupabaseClient,owner:string,id:string,pageInput:number){
 const work=await managerPreventiveDetail(client,owner,id),access=await managerAccess(client,owner);if(!work||!access)throw new Error('Approved plan access required.');
 const query=(head=false)=>client.from('preventive_maintenance_occurrences').select('organization_id,plan_id,due_on,event_id,work_order_id,created_at,snapshot',{head,count:'exact'}).eq('organization_id',access.organization).eq('plan_id',id);
 const count=await query(true);if(count.error||!Number.isSafeInteger(count.count)||count.count!<0)throw new Error('Preventive audit unavailable.');const total=count.count!,pages=Math.max(1,Math.ceil(total/25)),page=Math.min(Math.max(1,Number.isSafeInteger(pageInput)?pageInput:1),pages);
 const response=total?await query().order('due_on',{ascending:false}).range((page-1)*25,page*25-1):{data:[],error:null};if(response.error||!Array.isArray(response.data)||response.data.length>25)throw new Error('Preventive audit unavailable.');
 const rows=response.data.map(r=>{if(r.organization_id!==access.organization||r.plan_id!==id||!validId(r.event_id)||!validId(r.work_order_id)||typeof r.created_at!=='string'||!Number.isFinite(Date.parse(r.created_at)))throw new Error('Invalid preventive occurrence.');const scope=preventiveSnapshot(r.snapshot,id,access.organization);if(scope.due!==r.due_on||scope.state!=='active')throw new Error('Invalid occurrence scope.');return {due:scope.due,event:r.event_id as string,work:r.work_order_id as string,scope,created:r.created_at as string};});for(const key of ['due','event','work'] as const)if(new Set(rows.map(r=>r[key])).size!==rows.length)throw new Error('Duplicate occurrences.');
 const current=await managerAccess(client,owner);if(!current||current.organization!==access.organization||current.role!==access.role||current.revision!==access.revision||!await managerPreventiveDetail(client,owner,id))throw new Error('Plan access changed.');return {total,pages,page,rows};
}
