import type {SupabaseClient} from '@supabase/supabase-js';
import {invoiceInput} from '../../../lib/finance/invoice-validation';
import {invoiceAccess} from './invoice-access';
import {financeInvoiceDetail} from './finance-invoice-detail';
import {financeInvoiceHistory} from './finance-invoice-history';
import {financeInvoiceEvidence} from './finance-invoice-evidence';
import {EnquiryFailure} from './enquiries';
export type InvoiceCommand=Readonly<{request_id:string;action:'review'|'approve'|'reject';invoice_id:string;version:number;reason:string;approved:true}>;
export function financeInvoiceCommand(value:InvoiceCommand):InvoiceCommand{if(!['review','approve','reject'].includes(value.action))throw Error('Choose a review decision.');const r=invoiceInput(value);return Object.freeze({request_id:r.p_request_id,action:r.p_action as InvoiceCommand['action'],invoice_id:r.p_invoice_id!,version:r.p_expected_version,reason:r.p_reason,approved:true});}
export async function sendFinanceInvoice(client:SupabaseClient,owner:string,value:InvoiceCommand){
 let input:InvoiceCommand,access:NonNullable<Awaited<ReturnType<typeof invoiceAccess>>>;
 try{input=financeInvoiceCommand(value);const current=await invoiceAccess(client,owner);if(!current||!['admin','finance'].includes(current.role))throw Error();access=current;const invoice=await financeInvoiceDetail(client,owner,input.invoice_id);if(!invoice||invoice.submitter===owner||input.action==='approve'&&invoice.reviewer===owner)throw Error();if(input.action!=='reject'){const evidence=await financeInvoiceEvidence(client,owner,input.invoice_id);if(!evidence.sourceReady||input.action==='approve'&&!evidence.sealed)throw Error();}}catch{throw new EnquiryFailure('Check independent finance authority, current invoice and certified source.',false);}
 let response;try{response=await client.rpc('manage_vendor_invoice',invoiceInput(input));}catch{throw new EnquiryFailure('Invoice decision could not be confirmed. Retry the same request.',true);}
 if(response.error)throw new EnquiryFailure('Invoice decision could not be confirmed. Refresh or retry the same request.',!['42501','22023','22P02','40001','23505'].includes(response.error.code));
 try{const ack=response.data,version=input.version+1,state=input.action==='review'?'under_review':input.action==='approve'?'approved':'rejected';if(!ack||ack.id!==input.invoice_id||ack.version!==version||ack.state!==state)throw Error();
 const result=await client.from('vendor_invoice_reviews').select('invoice_id,organization_id,actor_user_id,request_id,payload,action,new_state,version,reason').eq('invoice_id',input.invoice_id).eq('organization_id',access.organization).eq('actor_user_id',owner).eq('request_id',input.request_id).maybeSingle(),event=result.data;
 const expected={action:input.action,invoice_id:input.invoice_id,version:input.version,property_id:null,work_order_id:null,vendor_name:null,invoice_number:null,amount_minor:null,reason:input.reason};
 if(result.error||!event||event.invoice_id!==input.invoice_id||event.organization_id!==access.organization||event.actor_user_id!==owner||event.request_id!==input.request_id||event.action!==input.action||event.new_state!==state||event.version!==version||event.reason!==input.reason||!event.payload||Object.entries(expected).some(([key,val])=>event.payload[key]!==val))throw Error();
 const history=await financeInvoiceHistory(client,owner,input.invoice_id);if(!history.rows.some(e=>e.actor===owner&&e.request===input.request_id&&e.version===version&&e.state===state&&e.action===input.action&&e.reason===input.reason)||history.invoice.version<version)throw Error();if(input.action!=='reject'){const evidence=await financeInvoiceEvidence(client,owner,input.invoice_id);if(!evidence.sealed||!evidence.sourceReady)throw Error();}
 const current=await invoiceAccess(client,owner);if(!current||current.organization!==access.organization||current.role!==access.role||current.revision!==access.revision)throw Error();return {id:input.invoice_id,version,state,currentVersion:history.invoice.version,currentState:history.invoice.state};
 }catch{throw new EnquiryFailure('Recorded invoice decision could not be verified. Retry the same request.',true);}
}
