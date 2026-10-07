import type {SupabaseClient} from '@supabase/supabase-js';
import {chequeInput} from '../../../lib/finance/cheque-validation';
import {financeAccess} from './finance-access';
import {financeChequeHistory} from './finance-cheque-history';
import {financeChequeBankHistory} from './finance-cheque-bank-history';
import {financeChequeEvidence} from './finance-cheque-evidence';
import {EnquiryFailure} from './enquiries';
export type ChequeCommand=Readonly<{request_id:string;action:'cancel'|'record_deposit'|'confirm_clear'|'record_return';cheque_id:string;version:number;evidence_id:string|null;bank_reference:string|null;reason:string;approved:true}>;
export function financeChequeCommand(value:ChequeCommand):ChequeCommand{if(!['cancel','record_deposit','confirm_clear','record_return'].includes(value.action))throw Error('Choose a custody decision.');const r=chequeInput(value);return Object.freeze({request_id:r.p_request_id,action:r.p_action as ChequeCommand['action'],cheque_id:r.p_cheque_id!,version:r.p_expected_version,evidence_id:r.p_evidence_id,bank_reference:r.p_bank_reference,reason:r.p_reason,approved:true});}
const kinds={record_deposit:'deposit',confirm_clear:'clearance',record_return:'return'} as const;
export async function sendFinanceCheque(client:SupabaseClient,owner:string,value:ChequeCommand){
 let input:ChequeCommand,access:NonNullable<Awaited<ReturnType<typeof financeAccess>>>;
 try{input=financeChequeCommand(value);const current=await financeAccess(client,owner);if(!current)throw Error();access=current;await financeChequeHistory(client,owner,input.cheque_id);
 if(input.action!=='cancel'){const evidence=await financeChequeEvidence(client,owner,input.cheque_id),file=evidence.rows.find(f=>f.id===input.evidence_id);if(!file||file.kind!==kinds[input.action]||file.usedVersion!==null&&file.usedVersion!==input.version+1)throw Error();}
 }catch{throw new EnquiryFailure('Check verified finance authority, cheque and matching certified bank evidence.',false);}
 let result;try{result=await client.rpc('manage_cheque_custody',chequeInput(input));}catch{throw new EnquiryFailure('Custody decision could not be confirmed. Retry the same request.',true);}
 if(result.error)throw new EnquiryFailure('Custody decision could not be confirmed. Check or retry the same request.',!['42501','22023','22P02','40001','23505'].includes(result.error.code));
 try{const state=input.action==='cancel'?'cancelled':input.action==='record_deposit'?'deposited':input.action==='confirm_clear'?'cleared':'returned',version=input.version+1,ack=result.data;if(!ack||ack.id!==input.cheque_id||ack.version!==version||ack.state!==state)throw Error();
 const audit=await client.from('cheque_custody_events').select('id,cheque_id,organization_id,actor_user_id,request_id,payload,action,new_state,version,reason').eq('cheque_id',input.cheque_id).eq('organization_id',access.organization).eq('actor_user_id',owner).eq('request_id',input.request_id).maybeSingle(),a=audit.data;
 const expected={action:input.action,cheque_id:input.cheque_id,version:input.version,property_id:null,payer_name:null,bank_name:null,cheque_reference:null,amount_minor:null,reason:input.reason,...(input.action==='cancel'?{}:{evidence_id:input.evidence_id,bank_reference:input.bank_reference})};
 if(audit.error||!a||a.cheque_id!==input.cheque_id||a.organization_id!==access.organization||a.actor_user_id!==owner||a.request_id!==input.request_id||a.action!==input.action||a.new_state!==state||a.version!==version||a.reason!==input.reason||!a.payload||Object.entries(expected).some(([k,v])=>a.payload[k]!==v))throw Error();
 const history=await financeChequeHistory(client,owner,input.cheque_id);if(!history.rows.some(e=>e.id===a.id&&e.actor===owner&&e.request===input.request_id&&e.action===input.action&&e.state===state&&e.version===version&&e.reason===input.reason)||history.cheque.version<version)throw Error();
 if(input.action!=='cancel'){const bank=await financeChequeBankHistory(client,owner,input.cheque_id);if(!bank.rows.some(f=>f.event===a.id&&f.evidence===input.evidence_id&&f.version===version&&f.kind===kinds[input.action as keyof typeof kinds]&&f.bankReference===input.bank_reference))throw Error();}
 const current=await financeAccess(client,owner);if(!current||current.organization!==access.organization||current.role!==access.role||current.revision!==access.revision)throw Error();return {id:input.cheque_id,version,state,currentVersion:history.cheque.version,currentState:history.cheque.state};
 }catch{throw new EnquiryFailure('Recorded custody decision could not be verified. Keep and retry the same request.',true);}
}
