import type {SupabaseClient} from '@supabase/supabase-js';
import {chequePostingInput} from '../../../lib/finance/cheque-posting';
import {financeAccess} from './finance-access';
import {financeAccount} from './finance-account';
import {financeChequePosting} from './finance-cheque-posting';
import {financeChequeBankHistory} from './finance-cheque-bank-history';
import {validId} from './catalog';
import {EnquiryFailure} from './enquiries';
export type ChequePostCommand=Readonly<{request_id:string;cheque_id:string;version:number;debit_account_id:string;credit_account_id:string;reason:string;approved:true}>;
export function financeChequePostCommand(value:ChequePostCommand):ChequePostCommand{const r=chequePostingInput(value);return Object.freeze({request_id:r.p_request_id,cheque_id:r.p_cheque_id,version:r.p_expected_version,debit_account_id:r.p_debit_account_id,credit_account_id:r.p_credit_account_id,reason:r.p_reason,approved:true});}
export async function postFinanceCheque(client:SupabaseClient,owner:string,value:ChequePostCommand){
 let input:ChequePostCommand,access:NonNullable<Awaited<ReturnType<typeof financeAccess>>>;
 try{input=financeChequePostCommand(value);const current=await financeAccess(client,owner);if(!current)throw Error();access=current;
 const snapshot=await financeChequePosting(client,owner,input.cheque_id);if(!snapshot.posting&&(snapshot.cheque.state!=='cleared'||snapshot.cheque.version!==input.version))throw Error();
 if(snapshot.posting&&(snapshot.posting.version!==input.version||snapshot.posting.actor!==owner||snapshot.posting.request!==input.request_id||snapshot.posting.debit!==input.debit_account_id||snapshot.posting.credit!==input.credit_account_id||snapshot.posting.reason!==input.reason))throw Error();
 const debit=await financeAccount(client,owner,input.debit_account_id),credit=await financeAccount(client,owner,input.credit_account_id);if(debit.classification!=='asset'||!['asset','liability','equity','income','expense'].includes(credit.classification))throw Error();
 const evidence=await financeChequeBankHistory(client,owner,input.cheque_id);if(evidence.cheque.version!==snapshot.cheque.version||evidence.cheque.state!==snapshot.cheque.state||!evidence.rows.some(row=>row.kind==='clearance'&&row.version===input.version))throw Error();
 }catch{throw new EnquiryFailure('Check current finance authority, cleared cheque, certified bank source and distinct approved accounts with an asset debit.',false);}
 let result;try{result=await client.rpc('post_cleared_cheque',chequePostingInput(input));}catch{throw new EnquiryFailure('Posting could not be confirmed. Keep and retry the same request.',true);}
 if(result.error)throw new EnquiryFailure('Posting could not be confirmed. Check or retry the same request.',!['42501','22023','22P02','40001','23505'].includes(result.error.code));
 try{if(!validId(result.data))throw Error();const snapshot=await financeChequePosting(client,owner,input.cheque_id),p=snapshot.posting;
 if(!p||p.journal!==result.data||p.actor!==owner||p.request!==input.request_id||p.version!==input.version||p.debit!==input.debit_account_id||p.credit!==input.credit_account_id||p.reason!==input.reason)throw Error();
 const current=await financeAccess(client,owner);if(!current||current.organization!==access.organization||current.role!==access.role||current.revision!==access.revision)throw Error();
 return {cheque:input.cheque_id,journal:p.journal,version:p.version,reversal:p.reversal};
 }catch{throw new EnquiryFailure('Recorded cheque posting could not be verified. Retry the same request.',true);}
}
