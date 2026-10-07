import type {SupabaseClient} from '@supabase/supabase-js';
import {invoiceAccess} from './invoice-access';
import {financeInvoiceDetail} from './finance-invoice-detail';
import {validId} from './catalog';
export async function financeInvoiceEvidence(client:SupabaseClient,owner:string,id:string){
 if(!validId(id))throw Error('Valid invoice reference required.');const access=await invoiceAccess(client,owner);if(!access)throw Error('Verified invoice membership required.');const invoice=await financeInvoiceDetail(client,owner,id);if(!invoice)throw Error('Invoice unavailable.');
 const uploaded=await client.from('vendor_invoice_evidence').select('id,invoice_id,organization_id,user_id,kind,file_name,mime_type,state,sha256,actual_size').eq('invoice_id',id).eq('organization_id',access.organization).eq('state','uploaded').order('id',{ascending:true}).limit(11);
 if(uploaded.error||!Array.isArray(uploaded.data)||uploaded.data.length>10)throw Error('Invoice documents unavailable.');
 const files=uploaded.data.map(r=>{const size=typeof r.actual_size==='string'&&/^[1-9]\d*$/.test(r.actual_size)?Number(r.actual_size):r.actual_size;if(!validId(r.id)||r.invoice_id!==id||r.organization_id!==access.organization||r.user_id!==invoice.submitter||r.state!=='uploaded'||!['invoice','supporting'].includes(r.kind)||typeof r.file_name!=='string'||!r.file_name.trim()||r.file_name.length>160||/[\x00-\x1f\x7f/\\]/.test(r.file_name)||!['application/pdf','image/jpeg','image/png'].includes(r.mime_type)||typeof r.sha256!=='string'||!/^[a-f0-9]{64}$/.test(r.sha256)||!Number.isSafeInteger(size)||size<1||size>8388608)throw Error('Invalid certified invoice document.');return {id:r.id as string,kind:r.kind as 'invoice'|'supporting',name:r.file_name as string,mime:r.mime_type as string,size:size as number,sha:r.sha256 as string};});
 if(new Set(files.map(f=>f.id)).size!==files.length)throw Error('Duplicate invoice documents.');
 const snapshot=await client.from('vendor_invoice_review_evidence').select('invoice_id,evidence_id,organization_id,reviewed_version,kind,file_name,mime_type,sha256,actual_size').eq('invoice_id',id).eq('organization_id',access.organization).order('evidence_id',{ascending:true}).limit(11);
 if(snapshot.error||!Array.isArray(snapshot.data)||snapshot.data.length>10)throw Error('Reviewed invoice documents unavailable.');
 const sealed=invoice.reviewer!==null;
 if(!sealed&&snapshot.data.length||sealed&&(snapshot.data.length!==files.length||!files.some(f=>f.kind==='invoice')))throw Error('Complete reviewed document snapshot required.');
 const seen=new Set<string>();for(const r of snapshot.data){const file=files.find(f=>f.id===r.evidence_id);if(!file||seen.has(r.evidence_id)||r.invoice_id!==id||r.organization_id!==access.organization||r.reviewed_version!==2||r.kind!==file.kind||r.file_name!==file.name||r.mime_type!==file.mime||r.sha256!==file.sha||String(r.actual_size)!==String(file.size))throw Error('Reviewed document differs from certified source.');seen.add(r.evidence_id);}
 const currentInvoice=await financeInvoiceDetail(client,owner,id),current=await invoiceAccess(client,owner);if(!current||current.organization!==access.organization||current.role!==access.role||current.revision!==access.revision||!currentInvoice||currentInvoice.version!==invoice.version||currentInvoice.state!==invoice.state)throw Error('Invoice document access changed.');
 return {invoice,sealed,sourceReady:files.some(f=>f.kind==='invoice'),rows:files.map(({sha,...file})=>{void sha;return file;})};
}
