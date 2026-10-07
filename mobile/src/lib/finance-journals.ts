import type {SupabaseClient} from '@supabase/supabase-js';
import {financeAccess} from './finance-access';
import {validId} from './catalog';
export async function financeJournals(client:SupabaseClient,owner:string,pageInput:number){
 const access=await financeAccess(client,owner);if(!access)throw Error('Approved finance membership required.');
 const query=(head=false)=>client.from('finance_journals').select('id,organization_id,memo,reason,currency,posted_by,posted_at',{head,count:'exact'}).eq('organization_id',access.organization);
 const count=await query(true);if(count.error||!Number.isSafeInteger(count.count)||count.count!<0)throw Error('Journal history unavailable.');
 const total=count.count!,pages=Math.max(1,Math.ceil(total/25)),page=Math.min(Math.max(1,Number.isSafeInteger(pageInput)?pageInput:1),pages);
 const response=total?await query().order('posted_at',{ascending:false}).order('id',{ascending:true}).range((page-1)*25,page*25-1):{data:[],error:null};
 if(response.error||!Array.isArray(response.data)||response.data.length>25)throw Error('Journal history unavailable.');
 const rows=response.data.map(r=>{
  if(!validId(r.id)||r.organization_id!==access.organization||typeof r.memo!=='string'||r.memo.trim().length<5||r.memo.length>1000||typeof r.reason!=='string'||r.reason.trim().length<5||r.reason.length>500||r.currency!=='JMD'||!validId(r.posted_by)||typeof r.posted_at!=='string'||!Number.isFinite(Date.parse(r.posted_at)))throw Error('Invalid posted journal.');
  return {id:r.id as string,memo:r.memo as string,reason:r.reason as string,actor:r.posted_by as string,posted:r.posted_at as string};
 });
 if(new Set(rows.map(r=>r.id)).size!==rows.length)throw Error('Duplicate posted journals.');
 const current=await financeAccess(client,owner);if(!current||current.organization!==access.organization||current.role!==access.role||current.revision!==access.revision)throw Error('Finance membership changed.');
 return {total,pages,page,rows,role:access.role};
}
