import type {SupabaseClient} from '@supabase/supabase-js';
import {reportPeriod} from '../../../lib/reports/period';
import {managerAccess} from './manager-access';
export async function managerMaintenanceReport(client:SupabaseClient,owner:string,start:string,end:string){
 const period=reportPeriod({start,end}),access=await managerAccess(client,owner);if(!access)throw Error('Management membership required.');
 const states=['reported','triaged','assigned','scheduled','on_site','in_progress','completed','closed','cancelled'],open=states.slice(0,6),metrics=[...states.map(state=>({key:state,state,priority:''})),...['urgent','high','standard','low'].map(priority=>({key:'priority-'+priority,state:'',priority}))];
 const rows=await Promise.all(metrics.map(async metric=>{let q=client.from('work_orders').select('id',{head:true,count:'exact'}).eq('organization_id',access.organization);q=metric.state?q.eq('status',metric.state):q.eq('priority',metric.priority).in('status',open);if(period)q=q.gte('created_at',period.from).lt('created_at',period.until);try{const r=await q;return {...metric,count:!r.error&&Number.isSafeInteger(r.count)&&r.count!>=0?r.count!:null};}catch{return {...metric,count:null};}}));
 const current=await managerAccess(client,owner);if(!current||current.organization!==access.organization||current.role!==access.role||current.revision!==access.revision)throw Error('Management access changed.');return {period,rows};
}
