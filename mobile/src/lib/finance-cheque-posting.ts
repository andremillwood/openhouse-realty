import type {SupabaseClient} from '@supabase/supabase-js';
import {financeAccess} from './finance-access';
import {financeChequeHistory} from './finance-cheque-history';
import {financeChequeBankHistory} from './finance-cheque-bank-history';
import {financeJournalDetail} from './finance-journal-detail';
import {validId} from './catalog';
export async function financeChequePosting(client:SupabaseClient,owner:string,id:string){
 if(!validId(id))throw Error('Valid cheque reference required.');const access=await financeAccess(client,owner);if(!access)throw Error('Verified finance authority required.');
 const history=await financeChequeHistory(client,owner,id),cheque=history.cheque;
 const response=await client.from('cheque_ledger_postings').select('cheque_id,organization_id,journal_id,clearance_event_id,cleared_version,debit_account_id,credit_account_id,actor_user_id,request_id,reason,posted_at').eq('cheque_id',id).eq('organization_id',access.organization).maybeSingle();if(response.error)throw Error('Cheque posting unavailable.');const r=response.data;
 let posting=null;
 if(r){if(r.cheque_id!==id||r.organization_id!==access.organization||!['cleared','returned'].includes(cheque.state)||r.cleared_version!==3||![r.journal_id,r.clearance_event_id,r.debit_account_id,r.credit_account_id,r.actor_user_id,r.request_id].every(validId)||r.debit_account_id===r.credit_account_id||typeof r.reason!=='string'||r.reason.trim().length<5||r.reason.length>500||typeof r.posted_at!=='string'||!Number.isFinite(Date.parse(r.posted_at)))throw Error('Invalid cheque posting.');
 if(!history.rows.some(e=>e.id===r.clearance_event_id&&e.action==='confirm_clear'&&e.state==='cleared'&&e.version===r.cleared_version))throw Error('Cheque approval source unavailable.');
 const evidence=await financeChequeBankHistory(client,owner,id);if(evidence.cheque.version!==cheque.version||evidence.cheque.state!==cheque.state||!evidence.rows.some(e=>e.event===r.clearance_event_id&&e.kind==='clearance'&&e.version===r.cleared_version))throw Error('Frozen cheque source unavailable.');
 const journal=await financeJournalDetail(client,owner,r.journal_id);
 if(!journal||journal.actor!==r.actor_user_id||journal.request!==r.request_id||journal.reason!==r.reason||journal.memo!=='Cleared cheque '+id||journal.incoming||journal.lines.length!==2||journal.debit!==cheque.amount||journal.credit!==cheque.amount)throw Error('Cheque journal unavailable.');
 const debit=journal.lines.find(l=>l.account===r.debit_account_id),credit=journal.lines.find(l=>l.account===r.credit_account_id);
 if(!debit||!credit||debit.debit!==cheque.amount||debit.credit!=='0'||credit.credit!==cheque.amount||credit.debit!=='0'||journal.lines.some(l=>l.property!==cheque.property||l.unit!==null))throw Error('Cheque journal allocation differs.');
 if(cheque.state==='returned'&&!journal.outgoing)throw Error('Returned cheque reversal unavailable.');
 if(journal.outgoing){const reversed=await financeJournalDetail(client,owner,journal.outgoing.reversal);
 if(!reversed||reversed.incoming?.original!==journal.id||reversed.incoming.reversal!==reversed.id||reversed.actor!==journal.outgoing.actor||reversed.reason!==journal.outgoing.reason||reversed.outgoing||reversed.lines.length!==2||reversed.debit!==cheque.amount||reversed.credit!==cheque.amount)throw Error('Cheque reversal journal unavailable.');
 const debitUndo=reversed.lines.find(l=>l.account===r.debit_account_id),creditUndo=reversed.lines.find(l=>l.account===r.credit_account_id);
 if(!debitUndo||!creditUndo||debitUndo.debit!=='0'||debitUndo.credit!==cheque.amount||creditUndo.credit!=='0'||creditUndo.debit!==cheque.amount||reversed.lines.some(l=>l.property!==cheque.property||l.unit!==null))throw Error('Cheque reversal allocation differs.');
 }
 posting={journal:journal.id,clearance:r.clearance_event_id as string,version:r.cleared_version as number,debit:r.debit_account_id as string,credit:r.credit_account_id as string,actor:r.actor_user_id as string,request:r.request_id as string,reason:r.reason as string,posted:r.posted_at as string,reversal:journal.outgoing};
 }
 const latest=await financeChequeHistory(client,owner,id),current=await financeAccess(client,owner);if(latest.cheque.version!==cheque.version||latest.cheque.state!==cheque.state||!current||current.organization!==access.organization||current.role!==access.role||current.revision!==access.revision)throw Error('Cheque authority or revision changed.');
 return {cheque,posting};
}
