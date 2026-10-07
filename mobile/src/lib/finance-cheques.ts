import type {SupabaseClient} from '@supabase/supabase-js';
import {financeAccess} from './finance-access';
import {validId} from './catalog';
export const chequeStates=['received','deposited','cleared','returned','cancelled'] as const;
export type ChequeState=typeof chequeStates[number];
export async function financeCheques(client:SupabaseClient,owner:string,pageInput:number,state:ChequeState|null=null){
 if(state!==null&&!chequeStates.includes(state))throw Error('Invalid cheque filter.');
 const access=await financeAccess(client,owner);if(!access)throw Error('Verified cheque membership required.');
 const query=(head=false)=>{let q=client.from('audited_cheque_receipts').select('id,organization_id,property_id,payer_name,bank_name,cheque_reference,amount_minor,currency,state,received_at',{head,count:'exact'}).eq('organization_id',access.organization);if(state)q=q.eq('state',state);return q;};
 const count=await query(true);if(count.error||!Number.isSafeInteger(count.count)||count.count!<0)throw Error('Cheque register unavailable.');
 const total=count.count!,pages=Math.max(1,Math.ceil(total/25)),page=Math.min(Math.max(1,Number.isSafeInteger(pageInput)?pageInput:1),pages);
 const response=total?await query().order('received_at',{ascending:false}).order('id',{ascending:true}).range((page-1)*25,page*25-1):{data:[],error:null};
 if(response.error||!Array.isArray(response.data)||response.data.length!==Math.min(25,Math.max(0,total-(page-1)*25)))throw Error('Cheque register changed or unavailable. Refresh.');
 const rows=response.data.map(r=>{
  const amount=typeof r.amount_minor==='string'?r.amount_minor:Number.isSafeInteger(r.amount_minor)?String(r.amount_minor):'';
  if(!validId(r.id)||r.organization_id!==access.organization||!validId(r.property_id)||typeof r.bank_name!=='string'||r.bank_name.trim().length<2||r.bank_name.length>160||/[\u0000-\u001f\u007f]/.test(r.bank_name)||typeof r.payer_name!=='string'||r.payer_name.trim().length<2||r.payer_name.length>160||typeof r.cheque_reference!=='string'||!r.cheque_reference.trim()||r.cheque_reference.length>80||/[\u0000-\u001f\u007f]/.test(r.payer_name+r.cheque_reference)||!(/^[1-9]\d{0,13}$/).test(amount)||BigInt(amount)>99999999999999n||r.currency!=='JMD'||!chequeStates.includes(r.state)||state!==null&&r.state!==state||typeof r.received_at!=='string'||!Number.isFinite(Date.parse(r.received_at)))throw Error('Invalid cheque record.');
  return {id:r.id as string,property:r.property_id as string,payer:r.payer_name as string,bank:r.bank_name as string,number:r.cheque_reference as string,amount,state:r.state as ChequeState,received:r.received_at as string};
 });
 if(new Set(rows.map(r=>r.id)).size!==rows.length)throw Error('Duplicate cheque records.');
 const current=await financeAccess(client,owner);if(!current||current.organization!==access.organization||current.role!==access.role||current.revision!==access.revision)throw Error('Cheque membership changed.');
 return {total,pages,page,rows,role:access.role,state};
}
