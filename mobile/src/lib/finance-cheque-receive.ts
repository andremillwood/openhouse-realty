import type {SupabaseClient} from '@supabase/supabase-js';
import {chequeInput} from '../../../lib/finance/cheque-validation';
import {financeAccess} from './finance-access';
import {financeChequeHistory} from './finance-cheque-history';
import {validId} from './catalog';
import {EnquiryFailure} from './enquiries';

export type ChequeReceipt=Readonly<{request_id:string;action:'receive';cheque_id:null;version:0;property_id:string;payer_name:string;bank_name:string;cheque_reference:string;amount_minor:number;reason:string;approved:true}>;
export function financeChequeReceipt(value:ChequeReceipt):ChequeReceipt{
 if(value.action!=='receive')throw Error('New cheque receipt required.');
 const r=chequeInput(value);
 return Object.freeze({request_id:r.p_request_id,action:'receive',cheque_id:null,version:0,property_id:r.p_property_id!,payer_name:r.p_payer_name!,bank_name:r.p_bank_name!,cheque_reference:r.p_cheque_reference!,amount_minor:r.p_amount_minor!,reason:r.p_reason,approved:true});
}
/** Receipt registration records custody only; it never credits a resident ledger. */
export async function receiveFinanceCheque(client:SupabaseClient,owner:string,value:ChequeReceipt){
 let input:ChequeReceipt,access:NonNullable<Awaited<ReturnType<typeof financeAccess>>>;
 try{input=financeChequeReceipt(value);const current=await financeAccess(client,owner);if(!current)throw Error();access=current;}catch{throw new EnquiryFailure('Check verified finance authority and approved receipt details.',false);}
 let response;try{response=await client.rpc('manage_cheque_custody',chequeInput(input));}catch{throw new EnquiryFailure('Receipt could not be confirmed. Retry the same request.',true);}
 if(response.error)throw new EnquiryFailure('Receipt could not be confirmed. Check or retry the same request.',!['42501','22023','22P02','40001','23505'].includes(response.error.code));
 try{
  const ack=response.data;if(!ack||!validId(ack.id)||ack.version!==1||ack.state!=='received')throw Error();
  const result=await client.from('cheque_custody_events').select('id,cheque_id,organization_id,actor_user_id,request_id,payload,action,previous_state,new_state,version,reason').eq('cheque_id',ack.id).eq('organization_id',access.organization).eq('actor_user_id',owner).eq('request_id',input.request_id).maybeSingle(),event=result.data;
  const expected={action:'receive',cheque_id:null,version:0,property_id:input.property_id,payer_name:input.payer_name,bank_name:input.bank_name,cheque_reference:input.cheque_reference,amount_minor:input.amount_minor,reason:input.reason};
  if(result.error||!event||!validId(event.id)||event.cheque_id!==ack.id||event.organization_id!==access.organization||event.actor_user_id!==owner||event.request_id!==input.request_id||event.action!=='receive'||event.previous_state!==null||event.new_state!=='received'||event.version!==1||event.reason!==input.reason||!event.payload||Object.entries(expected).some(([k,v])=>event.payload[k]!==v))throw Error();
  const history=await financeChequeHistory(client,owner,ack.id),cheque=history.cheque;
  if(cheque.receiver!==owner||cheque.property!==input.property_id||cheque.payer!==input.payer_name||cheque.bank!==input.bank_name||cheque.number!==input.cheque_reference||cheque.amount!==String(input.amount_minor)||!history.rows.some(e=>e.id===event.id&&e.actor===owner&&e.request===input.request_id&&e.version===1&&e.action==='receive'&&e.state==='received'&&e.reason===input.reason))throw Error();
  const current=await financeAccess(client,owner);if(!current||current.organization!==access.organization||current.role!==access.role||current.revision!==access.revision)throw Error();
  return {id:ack.id as string,version:1,state:'received' as const,currentVersion:cheque.version,currentState:cheque.state};
 }catch{throw new EnquiryFailure('Recorded receipt could not be verified. Keep and retry the same request.',true);}
}
