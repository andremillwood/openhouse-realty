import type {SupabaseClient} from '@supabase/supabase-js';
import {invoiceAccess} from './invoice-access';
import {validId} from './catalog';
export const invoiceStates=['submitted','under_review','approved','rejected'] as const;
export type InvoiceState=typeof invoiceStates[number];
export async function financeInvoices(client:SupabaseClient,owner:string,pageInput:number,state:InvoiceState|null=null){
 if(state!==null&&!invoiceStates.includes(state))throw Error('Invalid invoice filter.');
 const access=await invoiceAccess(client,owner);if(!access)throw Error('Verified invoice membership required.');
 const query=(head=false)=>{let q=client.from('reviewed_vendor_invoices').select('id,organization_id,vendor_name,invoice_number,amount_minor,currency,state,submitted_at',{head,count:'exact'}).eq('organization_id',access.organization);if(state)q=q.eq('state',state);return q;};
 const count=await query(true);if(count.error||!Number.isSafeInteger(count.count)||count.count!<0)throw Error('Invoice register unavailable.');
 const total=count.count!,pages=Math.max(1,Math.ceil(total/25)),page=Math.min(Math.max(1,Number.isSafeInteger(pageInput)?pageInput:1),pages);
 const response=total?await query().order('submitted_at',{ascending:false}).order('id',{ascending:true}).range((page-1)*25,page*25-1):{data:[],error:null};
 if(response.error||!Array.isArray(response.data)||response.data.length!==Math.min(25,Math.max(0,total-(page-1)*25)))throw Error('Invoice register changed or unavailable. Refresh.');
 const rows=response.data.map(r=>{
  const amount=typeof r.amount_minor==='string'?r.amount_minor:Number.isSafeInteger(r.amount_minor)?String(r.amount_minor):'';
  if(!validId(r.id)||r.organization_id!==access.organization||typeof r.vendor_name!=='string'||r.vendor_name.trim().length<2||r.vendor_name.length>160||typeof r.invoice_number!=='string'||!r.invoice_number.trim()||r.invoice_number.length>80||!(/^[1-9]\d{0,13}$/).test(amount)||BigInt(amount)>99999999999999n||r.currency!=='JMD'||!invoiceStates.includes(r.state)||state!==null&&r.state!==state||typeof r.submitted_at!=='string'||!Number.isFinite(Date.parse(r.submitted_at)))throw Error('Invalid invoice record.');
  return {id:r.id as string,vendor:r.vendor_name as string,number:r.invoice_number as string,amount,state:r.state as InvoiceState,submitted:r.submitted_at as string};
 });
 if(new Set(rows.map(r=>r.id)).size!==rows.length)throw Error('Duplicate invoice records.');
 const current=await invoiceAccess(client,owner);if(!current||current.organization!==access.organization||current.role!==access.role||current.revision!==access.revision)throw Error('Invoice membership changed.');
 return {total,pages,page,rows,role:access.role,state};
}
