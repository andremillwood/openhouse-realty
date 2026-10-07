import type {SupabaseClient} from '@supabase/supabase-js';
import {reversalInput} from '../../../lib/finance/reversal-validation';
import {financeAccess} from './finance-access';
import {financeJournalDetail} from './finance-journal-detail';
import {validId} from './catalog';
import {EnquiryFailure} from './enquiries';
export type ReversalCommand=Readonly<{journal_id:string;request_id:string;reason:string;approved:true}>;
export function financeReversalCommand(value:ReversalCommand):ReversalCommand{const r=reversalInput(value);return Object.freeze({journal_id:r.p_journal_id,request_id:r.p_request_id,reason:r.p_reason,approved:true});}
export async function sendFinanceReversal(client:SupabaseClient,owner:string,value:ReversalCommand){
 let input:ReversalCommand,access:NonNullable<Awaited<ReturnType<typeof financeAccess>>>,parent:NonNullable<Awaited<ReturnType<typeof financeJournalDetail>>>;
 try{input=financeReversalCommand(value);const current=await financeAccess(client,owner);if(!current)throw Error();access=current;const journal=await financeJournalDetail(client,owner,input.journal_id);if(!journal||journal.incoming)throw Error();parent=journal;const latest=await financeAccess(client,owner);if(!latest||latest.organization!==access.organization||latest.role!==access.role||latest.revision!==access.revision)throw Error();}catch{throw new EnquiryFailure('Check finance membership and approved original journal.',false);}
 let response;try{response=await client.rpc('reverse_finance_journal',reversalInput(input));}catch{throw new EnquiryFailure('Reversal could not be confirmed. Retry the same request.',true);}
 if(response.error)throw new EnquiryFailure('Reversal could not be confirmed. Refresh or retry the same request.',!['42501','22023','22P02','40001','23505'].includes(response.error.code));
 try{const ack=response.data;if(!validId(ack)||ack===input.journal_id)throw Error();const receipt=await client.from('finance_journal_reversals').select('organization_id,original_journal_id,reversal_journal_id,actor_user_id,request_id,reason').eq('organization_id',access.organization).eq('original_journal_id',input.journal_id).eq('reversal_journal_id',ack).eq('actor_user_id',owner).eq('request_id',input.request_id).maybeSingle(),r=receipt.data;
 if(receipt.error||!r||r.organization_id!==access.organization||r.original_journal_id!==input.journal_id||r.reversal_journal_id!==ack||r.actor_user_id!==owner||r.request_id!==input.request_id||r.reason!==input.reason)throw Error();
 const journal=await financeJournalDetail(client,owner,ack);if(!journal||journal.actor!==owner||journal.request!==input.request_id||journal.reason!==input.reason||journal.memo!=='Reversal of journal '+input.journal_id||journal.incoming?.original!==input.journal_id||journal.outgoing||journal.lines.length!==parent.lines.length||journal.lines.some((l,i)=>{const p=parent.lines[i];return l.number!==p.number||l.account!==p.account||l.property!==p.property||l.unit!==p.unit||l.debit!==p.credit||l.credit!==p.debit;}))throw Error();
 const latest=await financeAccess(client,owner);if(!latest||latest.organization!==access.organization||latest.role!==access.role||latest.revision!==access.revision)throw Error();return {id:ack,original:input.journal_id};
 }catch{throw new EnquiryFailure('Recorded reversal could not be verified. Retry the same request.',true);}
}
