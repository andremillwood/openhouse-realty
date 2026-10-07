import type {SupabaseClient} from '@supabase/supabase-js';
import {financeAccess} from './finance-access';
import {financeInvoiceHistory} from './finance-invoice-history';
import {financeInvoiceEvidence} from './finance-invoice-evidence';
import {financeJournalDetail} from './finance-journal-detail';
import {validId} from './catalog';
export async function financeInvoicePosting(client:SupabaseClient,owner:string,id:string){
 if(!validId(id))throw Error('Valid invoice reference required.');const access=await financeAccess(client,owner);if(!access)throw Error('Verified finance authority required.');
 const history=await financeInvoiceHistory(client,owner,id),invoice=history.invoice;
 const response=await client.from('vendor_invoice_ledger_postings').select('invoice_id,organization_id,journal_id,approval_event_id,approved_version,debit_account_id,credit_account_id,actor_user_id,request_id,reason,posted_at').eq('invoice_id',id).eq('organization_id',access.organization).maybeSingle();if(response.error)throw Error('Invoice posting unavailable.');const r=response.data;
 let posting=null;
 if(r){if(r.invoice_id!==id||r.organization_id!==access.organization||invoice.state!=='approved'||r.approved_version!==invoice.version||![r.journal_id,r.approval_event_id,r.debit_account_id,r.credit_account_id,r.actor_user_id,r.request_id].every(validId)||r.debit_account_id===r.credit_account_id||typeof r.reason!=='string'||r.reason.trim().length<5||r.reason.length>500||typeof r.posted_at!=='string'||!Number.isFinite(Date.parse(r.posted_at)))throw Error('Invalid invoice posting.');
 if(!history.rows.some(e=>e.id===r.approval_event_id&&e.action==='approve'&&e.state==='approved'&&e.version===r.approved_version&&e.actor===invoice.approver))throw Error('Invoice approval source unavailable.');
 const evidence=await financeInvoiceEvidence(client,owner,id);if(!evidence.sealed||!evidence.sourceReady||evidence.invoice.version!==invoice.version)throw Error('Frozen invoice source unavailable.');
 const journal=await financeJournalDetail(client,owner,r.journal_id);
 if(!journal||journal.actor!==r.actor_user_id||journal.request!==r.request_id||journal.reason!==r.reason||journal.memo!=='Approved vendor invoice '+id||journal.incoming||journal.lines.length!==2||journal.debit!==invoice.amount||journal.credit!==invoice.amount)throw Error('Invoice journal unavailable.');
 const debit=journal.lines.find(l=>l.account===r.debit_account_id),credit=journal.lines.find(l=>l.account===r.credit_account_id);
 if(!debit||!credit||debit.debit!==invoice.amount||debit.credit!=='0'||credit.credit!==invoice.amount||credit.debit!=='0'||journal.lines.some(l=>l.property!==invoice.property||l.unit!==null))throw Error('Invoice journal allocation differs.');
 posting={journal:journal.id,approval:r.approval_event_id as string,version:r.approved_version as number,debit:r.debit_account_id as string,credit:r.credit_account_id as string,actor:r.actor_user_id as string,request:r.request_id as string,reason:r.reason as string,posted:r.posted_at as string,reversal:journal.outgoing};
 }
 const latest=await financeInvoiceHistory(client,owner,id),current=await financeAccess(client,owner);if(latest.invoice.version!==invoice.version||latest.invoice.state!==invoice.state||!current||current.organization!==access.organization||current.role!==access.role||current.revision!==access.revision)throw Error('Invoice authority or revision changed.');
 return {invoice,posting};
}
