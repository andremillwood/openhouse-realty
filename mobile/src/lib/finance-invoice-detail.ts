import type {SupabaseClient} from '@supabase/supabase-js';
import {invoiceAccess} from './invoice-access';
import {validId} from './catalog';
import {invoiceStates,type InvoiceState} from './finance-invoices';
import {invoiceActions} from '../../../lib/finance/invoice-actions';
const date=(v:unknown):v is string=>typeof v==='string'&&Number.isFinite(Date.parse(v));
export async function financeInvoiceDetail(client:SupabaseClient,owner:string,id:string){
 if(!validId(id))throw Error('Valid invoice reference required.');
 const access=await invoiceAccess(client,owner);if(!access)throw Error('Verified invoice membership required.');
 const response=await client.from('reviewed_vendor_invoices').select('id,organization_id,property_id,work_order_id,vendor_name,invoice_number,amount_minor,currency,state,version,submitted_by,reviewed_by,approved_by,submitted_at,reviewed_at,approved_at').eq('id',id).eq('organization_id',access.organization).maybeSingle();
 if(response.error)throw Error('Invoice detail unavailable.');const r=response.data;
 const current=await invoiceAccess(client,owner);if(!current||current.organization!==access.organization||current.role!==access.role||current.revision!==access.revision)throw Error('Invoice membership changed.');
 if(!r)return null;
 const amount=typeof r.amount_minor==='string'?r.amount_minor:Number.isSafeInteger(r.amount_minor)?String(r.amount_minor):'';
 if(r.id!==id||r.organization_id!==access.organization||r.property_id!==null&&!validId(r.property_id)||r.work_order_id!==null&&(!validId(r.work_order_id)||r.property_id===null)||typeof r.vendor_name!=='string'||r.vendor_name.trim().length<2||r.vendor_name.length>160||typeof r.invoice_number!=='string'||!r.invoice_number.trim()||r.invoice_number.length>80||!(/^[1-9]\d{0,13}$/).test(amount)||BigInt(amount)>99999999999999n||r.currency!=='JMD'||!invoiceStates.includes(r.state)||!Number.isSafeInteger(r.version)||r.version<1||r.version>2147483647||!validId(r.submitted_by)||!date(r.submitted_at))throw Error('Invalid invoice detail.');
 if((r.reviewed_by===null)!==(r.reviewed_at===null)||(r.approved_by===null)!==(r.approved_at===null)||r.reviewed_by!==null&&(!validId(r.reviewed_by)||r.reviewed_by===r.submitted_by||!date(r.reviewed_at))||r.approved_by!==null&&(!validId(r.approved_by)||r.approved_by===r.submitted_by||r.approved_by===r.reviewed_by||r.reviewed_by===null||!date(r.approved_at)))throw Error('Invalid independent invoice review.');
 if(r.state==='submitted'&&(r.version!==1||r.reviewed_by!==null||r.approved_by!==null)||r.state==='under_review'&&(r.version!==2||r.reviewed_by===null||r.approved_by!==null)||r.state==='approved'&&(r.version!==3||r.reviewed_by===null||r.approved_by===null)||r.state==='rejected'&&(r.approved_by!==null||r.version!==(r.reviewed_by===null?2:3)))throw Error('Invalid invoice revision.');
 return {id,vendor:r.vendor_name as string,number:r.invoice_number as string,amount,state:r.state as InvoiceState,version:r.version as number,property:r.property_id as string|null,work:r.work_order_id as string|null,submitter:r.submitted_by as string,reviewer:r.reviewed_by as string|null,approver:r.approved_by as string|null,submitted:r.submitted_at as string,reviewed:r.reviewed_at as string|null,approved:r.approved_at as string|null,role:access.role,actions:invoiceActions(r,owner,access.role)};
}
