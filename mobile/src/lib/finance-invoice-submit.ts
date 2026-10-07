import type {SupabaseClient} from '@supabase/supabase-js';
import {invoiceInput} from '../../../lib/finance/invoice-validation';
import {invoiceAccess} from './invoice-access';
import {financeInvoiceHistory} from './finance-invoice-history';
import {validId} from './catalog';
import {EnquiryFailure} from './enquiries';
export type InvoiceSubmission=Readonly<{request_id:string;action:'submit';invoice_id:null;version:0;property_id:string|null;work_order_id:string|null;vendor_name:string;invoice_number:string;amount_minor:number;reason:string;approved:true}>;
export function financeInvoiceSubmission(value:InvoiceSubmission):InvoiceSubmission{
 if(value.action!=='submit')throw Error('New invoice submission required.');const r=invoiceInput(value);
 return Object.freeze({request_id:r.p_request_id,action:'submit',invoice_id:null,version:0,property_id:r.p_property_id,work_order_id:r.p_work_order_id,vendor_name:r.p_vendor_name!,invoice_number:r.p_invoice_number!,amount_minor:r.p_amount_minor!,reason:r.p_reason,approved:true});
}
export async function submitFinanceInvoice(client:SupabaseClient,owner:string,value:InvoiceSubmission){
 let input:InvoiceSubmission,access:NonNullable<Awaited<ReturnType<typeof invoiceAccess>>>;
 try{input=financeInvoiceSubmission(value);const current=await invoiceAccess(client,owner);if(!current)throw Error();access=current;}catch{throw new EnquiryFailure('Check verified invoice authority and approved invoice details.',false);}
 let response;try{response=await client.rpc('manage_vendor_invoice',invoiceInput(input));}catch{throw new EnquiryFailure('Submission could not be confirmed. Retry the same request.',true);}
 if(response.error)throw new EnquiryFailure('Submission could not be confirmed. Retry or refresh the same request.',!['42501','22023','22P02','40001','23505'].includes(response.error.code));
 try{const ack=response.data;if(!ack||!validId(ack.id)||ack.version!==1||ack.state!=='submitted')throw Error();
 const result=await client.from('vendor_invoice_reviews').select('invoice_id,organization_id,actor_user_id,request_id,payload,action,previous_state,new_state,version,reason').eq('invoice_id',ack.id).eq('organization_id',access.organization).eq('actor_user_id',owner).eq('request_id',input.request_id).maybeSingle(),event=result.data;
 const expected={action:'submit',invoice_id:null,version:0,property_id:input.property_id,work_order_id:input.work_order_id,vendor_name:input.vendor_name,invoice_number:input.invoice_number,amount_minor:input.amount_minor,reason:input.reason};
 if(result.error||!event||event.invoice_id!==ack.id||event.organization_id!==access.organization||event.actor_user_id!==owner||event.request_id!==input.request_id||event.action!=='submit'||event.previous_state!==null||event.new_state!=='submitted'||event.version!==1||event.reason!==input.reason||!event.payload||Object.entries(expected).some(([k,v])=>event.payload[k]!==v))throw Error();
 const history=await financeInvoiceHistory(client,owner,ack.id),invoice=history.invoice;
 if(invoice.submitter!==owner||invoice.property!==input.property_id||invoice.work!==input.work_order_id||invoice.vendor!==input.vendor_name||invoice.number!==input.invoice_number||invoice.amount!==String(input.amount_minor)||!history.rows.some(e=>e.actor===owner&&e.request===input.request_id&&e.version===1&&e.action==='submit'&&e.state==='submitted'&&e.reason===input.reason))throw Error();
 const current=await invoiceAccess(client,owner);if(!current||current.organization!==access.organization||current.role!==access.role||current.revision!==access.revision)throw Error();
 return {id:ack.id as string,version:1,state:'submitted' as const,currentVersion:invoice.version,currentState:invoice.state};
 }catch{throw new EnquiryFailure('Recorded submission could not be verified. Keep and retry the same request.',true);}
}
