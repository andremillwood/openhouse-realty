import type {SupabaseClient} from '@supabase/supabase-js';
import {financeAccess} from './finance-access';
import {validId} from './catalog';
import {chequeStates,type ChequeState} from './finance-cheques';
const date=(v:unknown):v is string=>typeof v==='string'&&Number.isFinite(Date.parse(v));
const text=(v:unknown,min:number,max:number):v is string=>typeof v==='string'&&v.trim().length>=min&&v.length<=max&&!/[\u0000-\u001f\u007f]/.test(v);
export async function financeChequeDetail(client:SupabaseClient,owner:string,id:string){
 if(!validId(id))throw Error('Valid cheque reference required.');const access=await financeAccess(client,owner);if(!access)throw Error('Verified finance membership required.');
 const response=await client.from('audited_cheque_receipts').select('id,organization_id,property_id,payer_name,bank_name,cheque_reference,amount_minor,currency,state,version,received_by,received_at,cancelled_at').eq('id',id).eq('organization_id',access.organization).maybeSingle();if(response.error)throw Error('Cheque detail unavailable.');const r=response.data;
 const current=await financeAccess(client,owner);if(!current||current.organization!==access.organization||current.role!==access.role||current.revision!==access.revision)throw Error('Finance authority changed.');if(!r)return null;
 const amount=typeof r.amount_minor==='string'?r.amount_minor:Number.isSafeInteger(r.amount_minor)?String(r.amount_minor):'';
 if(r.id!==id||r.organization_id!==access.organization||!validId(r.property_id)||!text(r.payer_name,2,160)||!text(r.bank_name,2,160)||!text(r.cheque_reference,1,80)||!/^[1-9]\d{0,13}$/.test(amount)||BigInt(amount)>99999999999999n||r.currency!=='JMD'||!chequeStates.includes(r.state)||!Number.isSafeInteger(r.version)||!validId(r.received_by)||!date(r.received_at)||(r.state==='cancelled')!==(r.cancelled_at!==null)||r.cancelled_at!==null&&!date(r.cancelled_at))throw Error('Invalid cheque detail.');
 const versions:Record<ChequeState,number[]>={received:[1],deposited:[2],cleared:[3],returned:[3,4],cancelled:[2]};if(!versions[r.state as ChequeState].includes(r.version))throw Error('Invalid cheque revision.');
 return {id,property:r.property_id as string,payer:r.payer_name,bank:r.bank_name,number:r.cheque_reference,amount,state:r.state as ChequeState,version:r.version as number,receiver:r.received_by as string,received:r.received_at,cancelled:r.cancelled_at as string|null,role:access.role};
}
