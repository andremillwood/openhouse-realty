import type {SupabaseClient} from '@supabase/supabase-js';
import {journalInput,type JournalLine} from '../../../lib/finance/journal-validation';
import {financeAccess} from './finance-access';
import {financeJournalDetail} from './finance-journal-detail';
import {validId} from './catalog';
import {EnquiryFailure} from './enquiries';
export type JournalCommand=Readonly<{request_id:string;currency:'JMD';memo:string;reason:string;approved:true;lines:readonly Readonly<JournalLine>[]} >;
export function financeJournalCommand(value:JournalCommand):JournalCommand{const r=journalInput(value);return Object.freeze({request_id:r.request_id,currency:r.currency,memo:r.memo,reason:r.reason,approved:true,lines:Object.freeze(r.lines.map(l=>Object.freeze({...l})))});}
export async function sendFinanceJournal(client:SupabaseClient,owner:string,value:JournalCommand){
 let input:JournalCommand,access:NonNullable<Awaited<ReturnType<typeof financeAccess>>>;
 try{input=financeJournalCommand(value);const current=await financeAccess(client,owner);if(!current)throw Error();access=current;}catch{throw new EnquiryFailure('Check finance membership and approved balanced journal fields.',false);}
 const r=journalInput(input);let response;try{response=await client.rpc('post_finance_journal',{p_request_id:r.request_id,p_currency:r.currency,p_memo:r.memo,p_reason:r.reason,p_approved:r.approved,p_lines:r.lines});}catch{throw new EnquiryFailure('Posting could not be confirmed. Retry the same request.',true);}
 if(response.error)throw new EnquiryFailure('Posting could not be confirmed. Refresh or retry the same request.',!['42501','22023','22P02','40001','23505'].includes(response.error.code));
 try{const id=response.data;if(!validId(id))throw Error();const journal=await financeJournalDetail(client,owner,id);if(!journal||journal.id!==id||journal.actor!==owner||journal.request!==input.request_id||journal.memo!==input.memo||journal.reason!==input.reason||journal.lines.length!==input.lines.length||journal.lines.some((l,i)=>{const p=input.lines[i];return l.number!==i+1||l.account!==p.account_id||l.property!==p.property_id||l.unit!==p.unit_id||l.debit!==String(p.debit_minor)||l.credit!==String(p.credit_minor);}))throw Error();
 const latest=await financeAccess(client,owner);if(!latest||latest.organization!==access.organization||latest.role!==access.role||latest.revision!==access.revision)throw Error();return {id,total:r.total_minor,reversed:!!journal.outgoing};
 }catch{throw new EnquiryFailure('Recorded posting could not be verified. Retry the same request.',true);}
}
