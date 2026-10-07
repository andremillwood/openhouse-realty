import type {SupabaseClient} from '@supabase/supabase-js';
import {invoiceAccess} from './invoice-access';
import {financeInvoiceDetail} from './finance-invoice-detail';
import {validId} from './catalog';
export async function financeInvoiceHistory(client:SupabaseClient,owner:string,id:string){
 if(!validId(id))throw Error('Valid invoice reference required.');const access=await invoiceAccess(client,owner);if(!access)throw Error('Verified invoice membership required.');
 const invoice=await financeInvoiceDetail(client,owner,id);if(!invoice)throw Error('Invoice unavailable.');
 // Current invoice transitions retain at most three events. Fetch one extra to detect corruption.
 const result=await client.from('vendor_invoice_reviews').select('id,organization_id,invoice_id,actor_user_id,request_id,action,previous_state,new_state,version,reason,created_at').eq('organization_id',access.organization).eq('invoice_id',id).order('version',{ascending:true}).limit(4);
 if(result.error||!Array.isArray(result.data)||result.data.length!==invoice.version)throw Error('Complete invoice history unavailable.');
 let state:string|null=null;
 const rows=result.data.map((r,i)=>{
  if(!validId(r.id)||r.organization_id!==access.organization||r.invoice_id!==id||!validId(r.actor_user_id)||!validId(r.request_id)||r.version!==i+1||r.previous_state!==state||typeof r.reason!=='string'||r.reason.trim().length<5||r.reason.length>500||typeof r.created_at!=='string'||!Number.isFinite(Date.parse(r.created_at)))throw Error('Invalid invoice history.');
  const expected=i===0?'submitted':r.action==='review'&&state==='submitted'?'under_review':r.action==='approve'&&state==='under_review'?'approved':r.action==='reject'&&['submitted','under_review'].includes(state??'')?'rejected':null;
  if(i===0&&(r.action!=='submit'||r.actor_user_id!==invoice.submitter)||i>0&&r.actor_user_id===invoice.submitter||r.action==='review'&&r.actor_user_id!==invoice.reviewer||r.action==='approve'&&(r.actor_user_id!==invoice.approver||r.actor_user_id===invoice.reviewer)||expected===null||r.new_state!==expected)throw Error('Invalid independent invoice history.');
  state=r.new_state;
  return {id:r.id as string,actor:r.actor_user_id as string,request:r.request_id as string,action:r.action as 'submit'|'review'|'approve'|'reject',previous:r.previous_state as string|null,state:r.new_state as string,version:r.version as number,reason:r.reason as string,created:r.created_at as string};
 });
 if(state!==invoice.state||new Set(rows.map(r=>r.id)).size!==rows.length||new Set(rows.map(r=>r.actor+':'+r.request)).size!==rows.length)throw Error('Invoice history differs from current record.');
 const currentInvoice=await financeInvoiceDetail(client,owner,id),current=await invoiceAccess(client,owner);
 if(!current||current.organization!==access.organization||current.role!==access.role||current.revision!==access.revision||!currentInvoice||currentInvoice.version!==invoice.version||currentInvoice.state!==invoice.state)throw Error('Invoice or membership changed. Refresh.');
 return {invoice,rows:rows.reverse()};
}
