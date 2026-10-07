import type {SupabaseClient} from '@supabase/supabase-js';
import {financeAccess} from './finance-access';
import {validId} from './catalog';
export async function financeAccounts(client:SupabaseClient,owner:string,pageInput:number){
 const access=await financeAccess(client,owner);if(!access)throw Error('Approved finance membership required.');
 const query=(head=false)=>client.from('finance_accounts').select('id,organization_id,code,name,account_class,approved_by,approval_reason,created_at',{head,count:'exact'}).eq('organization_id',access.organization);
 const count=await query(true);if(count.error||!Number.isSafeInteger(count.count)||count.count!<0)throw Error('Approved accounts unavailable.');
 const total=count.count!,pages=Math.max(1,Math.ceil(total/25)),page=Math.min(Math.max(1,Number.isSafeInteger(pageInput)?pageInput:1),pages);
 const response=total?await query().order('code',{ascending:true}).order('id',{ascending:true}).range((page-1)*25,page*25-1):{data:[],error:null};
 if(response.error||!Array.isArray(response.data)||response.data.length>25)throw Error('Approved accounts unavailable.');
 const rows=response.data.map(r=>{
  if(!validId(r.id)||r.organization_id!==access.organization||typeof r.code!=='string'||!(/^[A-Z0-9][A-Z0-9._-]{0,39}$/).test(r.code)||typeof r.name!=='string'||r.name.trim().length<2||r.name.length>120||!['asset','liability','equity','income','expense'].includes(r.account_class)||!validId(r.approved_by)||typeof r.approval_reason!=='string'||r.approval_reason.trim().length<5||r.approval_reason.length>500||typeof r.created_at!=='string'||!Number.isFinite(Date.parse(r.created_at)))throw Error('Invalid approved account.');
  return {id:r.id as string,code:r.code as string,name:r.name as string,classification:r.account_class as string,approver:r.approved_by as string,reason:r.approval_reason as string,created:r.created_at as string};
 });
 if(new Set(rows.map(r=>r.id)).size!==rows.length||new Set(rows.map(r=>r.code)).size!==rows.length)throw Error('Duplicate approved accounts.');
 const current=await financeAccess(client,owner);if(!current||current.organization!==access.organization||current.role!==access.role||current.revision!==access.revision)throw Error('Finance membership changed.');
 return {total,pages,page,rows,role:access.role};
}
