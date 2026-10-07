import type {SupabaseClient} from '@supabase/supabase-js';
import {invoicePostingInput} from '../../../lib/finance/invoice-posting';
import {financeAccess} from './finance-access';
import {financeAccount} from './finance-account';
import {financeInvoicePosting} from './finance-invoice-posting';
import {financeInvoiceEvidence} from './finance-invoice-evidence';
import {validId} from './catalog';
import {EnquiryFailure} from './enquiries';
export type InvoicePostCommand=Readonly<{request_id:string;invoice_id:string;version:number;debit_account_id:string;credit_account_id:string;reason:string;approved:true}>;
export function financeInvoicePostCommand(value:InvoicePostCommand):InvoicePostCommand{const r=invoicePostingInput(value);return Object.freeze({request_id:r.p_request_id,invoice_id:r.p_invoice_id,version:r.p_expected_version,debit_account_id:r.p_debit_account_id,credit_account_id:r.p_credit_account_id,reason:r.p_reason,approved:true});}
export async function postFinanceInvoice(client:SupabaseClient,owner:string,value:InvoicePostCommand){
 let input:InvoicePostCommand,access:NonNullable<Awaited<ReturnType<typeof financeAccess>>>;
 try{input=financeInvoicePostCommand(value);const current=await financeAccess(client,owner);if(!current)throw Error();access=current;
 const snapshot=await financeInvoicePosting(client,owner,input.invoice_id);if(snapshot.invoice.state!=='approved'||snapshot.invoice.version!==input.version)throw Error();
 if(snapshot.posting&&(snapshot.posting.actor!==owner||snapshot.posting.request!==input.request_id||snapshot.posting.debit!==input.debit_account_id||snapshot.posting.credit!==input.credit_account_id||snapshot.posting.reason!==input.reason))throw Error();
 const debit=await financeAccount(client,owner,input.debit_account_id),credit=await financeAccount(client,owner,input.credit_account_id);if(!['asset','expense'].includes(debit.classification)||credit.classification!=='liability')throw Error();
 const evidence=await financeInvoiceEvidence(client,owner,input.invoice_id);if(!evidence.sealed||!evidence.sourceReady||evidence.invoice.version!==input.version)throw Error();
 }catch{throw new EnquiryFailure('Check current finance authority, approved invoice, frozen source and asset/expense debit with liability credit.',false);}
 let result;try{result=await client.rpc('post_approved_vendor_invoice',invoicePostingInput(input));}catch{throw new EnquiryFailure('Posting could not be confirmed. Keep and retry the same request.',true);}
 if(result.error)throw new EnquiryFailure('Posting could not be confirmed. Check or retry the same request.',!['42501','22023','22P02','40001','23505'].includes(result.error.code));
 try{if(!validId(result.data))throw Error();const snapshot=await financeInvoicePosting(client,owner,input.invoice_id),p=snapshot.posting;
 if(!p||p.journal!==result.data||p.actor!==owner||p.request!==input.request_id||p.version!==input.version||p.debit!==input.debit_account_id||p.credit!==input.credit_account_id||p.reason!==input.reason)throw Error();
 const current=await financeAccess(client,owner);if(!current||current.organization!==access.organization||current.role!==access.role||current.revision!==access.revision)throw Error();
 return {invoice:input.invoice_id,journal:p.journal,version:p.version,reversal:p.reversal};
 }catch{throw new EnquiryFailure('Recorded invoice posting could not be verified. Retry the same request.',true);}
}
