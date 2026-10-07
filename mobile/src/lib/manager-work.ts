import type {SupabaseClient} from '@supabase/supabase-js';
import {managerAccess} from './manager-access';
import {validId} from './catalog';
export const workStates=['reported','triaged','assigned','scheduled','on_site','in_progress','completed','closed','cancelled'] as const;
export function workState(value:unknown):string{return typeof value==='string'&&(workStates as readonly string[]).includes(value)?value:'';}
export async function managerWork(client:SupabaseClient,owner:string,pageInput:number,stateInput:unknown){
 const access=await managerAccess(client,owner);if(!access)throw new Error('Approved manager membership required.');const state=workState(stateInput);
 const query=(head=false)=>{let q=client.from('work_orders').select('id,organization_id,title,priority,status,created_at',{head,count:'exact'}).eq('organization_id',access.organization);if(state)q=q.eq('status',state);return q;};
 const count=await query(true);if(count.error||!Number.isSafeInteger(count.count)||count.count!<0)throw new Error('Work queue unavailable.');const total=count.count!,pages=Math.max(1,Math.ceil(total/25)),page=Math.min(Math.max(1,Number.isSafeInteger(pageInput)?pageInput:1),pages);
 const response=total?await query().order('created_at',{ascending:false}).order('id',{ascending:true}).range((page-1)*25,page*25-1):{data:[],error:null};if(response.error||!Array.isArray(response.data)||response.data.length>25)throw new Error('Work queue unavailable.');
 const rows=response.data.map(r=>{if(!validId(r.id)||r.organization_id!==access.organization||typeof r.title!=='string'||!r.title.trim()||r.title.length>500||!workState(r.status)||state&&r.status!==state||!['urgent','high','standard','low'].includes(r.priority)||typeof r.created_at!=='string'||!Number.isFinite(Date.parse(r.created_at)))throw new Error('Invalid work order.');return {id:r.id as string,title:r.title as string,state:r.status as string,priority:r.priority as string,created:r.created_at as string};});if(new Set(rows.map(r=>r.id)).size!==rows.length)throw new Error('Invalid work orders.');
 const current=await managerAccess(client,owner);if(!current||current.organization!==access.organization||current.role!==access.role||current.revision!==access.revision)throw new Error('Management access changed.');return {total,pages,page,state,rows};
}
