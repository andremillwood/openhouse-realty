import type {SupabaseClient} from '@supabase/supabase-js';
import {financeAccess} from './finance-access';
import {financeChequeDetail} from './finance-cheque-detail';
import {validId} from './catalog';
export async function financeChequeHistory(client:SupabaseClient,owner:string,id:string){
 if(!validId(id))throw Error('Valid cheque reference required.');const access=await financeAccess(client,owner);if(!access)throw Error('Verified finance membership required.');const cheque=await financeChequeDetail(client,owner,id);if(!cheque)throw Error('Cheque unavailable.');
 const result=await client.from('cheque_custody_events').select('id,organization_id,cheque_id,actor_user_id,request_id,action,previous_state,new_state,version,reason,created_at').eq('organization_id',access.organization).eq('cheque_id',id).order('version',{ascending:true}).limit(5);
 if(result.error||!Array.isArray(result.data)||result.data.length!==cheque.version)throw Error('Complete cheque history unavailable.');let state:string|null=null;
 const rows=result.data.map((r,i)=>{
 if(!validId(r.id)||r.organization_id!==access.organization||r.cheque_id!==id||!validId(r.actor_user_id)||!validId(r.request_id)||r.version!==i+1||r.previous_state!==state||typeof r.reason!=='string'||r.reason.trim().length<5||r.reason.length>500||typeof r.created_at!=='string'||!Number.isFinite(Date.parse(r.created_at)))throw Error('Invalid cheque history.');
 const expected=i===0&&r.action==='receive'?'received':r.action==='cancel'&&state==='received'?'cancelled':r.action==='record_deposit'&&state==='received'?'deposited':r.action==='confirm_clear'&&state==='deposited'?'cleared':r.action==='record_return'&&['deposited','cleared'].includes(state??'')?'returned':null;
 if(expected===null||r.new_state!==expected||i===0&&r.actor_user_id!==cheque.receiver)throw Error('Invalid cheque custody sequence.');state=r.new_state;
 return {id:r.id as string,actor:r.actor_user_id as string,request:r.request_id as string,action:r.action as 'receive'|'cancel'|'record_deposit'|'confirm_clear'|'record_return',previous:r.previous_state as string|null,state:r.new_state as string,version:r.version as number,reason:r.reason as string,created:r.created_at as string};
 });
 if(state!==cheque.state||new Set(rows.map(r=>r.id)).size!==rows.length||new Set(rows.map(r=>r.actor+':'+r.request)).size!==rows.length)throw Error('Cheque history differs from the current record.');
 const latest=await financeChequeDetail(client,owner,id),current=await financeAccess(client,owner);if(!latest||latest.version!==cheque.version||latest.state!==cheque.state||!current||current.organization!==access.organization||current.role!==access.role||current.revision!==access.revision)throw Error('Cheque or authority changed.');return {cheque,rows:rows.reverse()};
}
