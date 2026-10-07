import type {SupabaseClient} from '@supabase/supabase-js';
import {financeAccountInput} from '../../../lib/finance/account-validation';
import {financeAccess} from './finance-access';
import {validId} from './catalog';
import {EnquiryFailure} from './enquiries';
export type AccountCommand=Readonly<{request_id:string;code:string;name:string;account_class:string;reason:string;approved:true}>;
export function financeAccountCommand(value:AccountCommand):AccountCommand{const r=financeAccountInput(value);return Object.freeze({request_id:r.p_request_id,code:r.p_code,name:r.p_name,account_class:r.p_account_class,reason:r.p_reason,approved:true});}
export async function sendFinanceAccount(client:SupabaseClient,owner:string,value:AccountCommand){
 let input:AccountCommand,access:NonNullable<Awaited<ReturnType<typeof financeAccess>>>;
 try{input=financeAccountCommand(value);const current=await financeAccess(client,owner);if(!current||current.role!=='admin')throw Error();access=current;}catch{throw new EnquiryFailure('Check administrator membership and approved account fields.',false);}
 let response;try{response=await client.rpc('author_finance_account',financeAccountInput(input));}catch{throw new EnquiryFailure('Account registration could not be confirmed. Retry the same request.',true);}
 if(response.error)throw new EnquiryFailure('Account registration could not be confirmed. Refresh or retry the same request.',!['42501','22023','22P02','40001','23505'].includes(response.error.code));
 try{const id=response.data;if(!validId(id))throw Error();const event=await client.from('finance_account_approvals').select('account_id,organization_id,actor_user_id,request_id,payload').eq('account_id',id).eq('organization_id',access.organization).eq('actor_user_id',owner).eq('request_id',input.request_id).maybeSingle(),r=event.data;
 if(event.error||!r||r.account_id!==id||r.organization_id!==access.organization||r.actor_user_id!==owner||r.request_id!==input.request_id||!r.payload||Object.entries({code:input.code,name:input.name,account_class:input.account_class,reason:input.reason,approved:true}).some(([k,v])=>r.payload[k]!==v))throw Error();
 const account=await client.from('finance_accounts').select('id,organization_id,code,name,account_class,approved_by,approval_reason').eq('id',id).eq('organization_id',access.organization).maybeSingle(),a=account.data;
 if(account.error||!a||a.id!==id||a.organization_id!==access.organization||a.code!==input.code||a.name!==input.name||a.account_class!==input.account_class||a.approved_by!==owner||a.approval_reason!==input.reason)throw Error();const latest=await financeAccess(client,owner);if(!latest||latest.organization!==access.organization||latest.role!==access.role||latest.revision!==access.revision)throw Error();return {id,code:input.code,name:input.name,classification:input.account_class};
 }catch{throw new EnquiryFailure('Recorded account approval could not be verified. Retry the same request.',true);}
}
