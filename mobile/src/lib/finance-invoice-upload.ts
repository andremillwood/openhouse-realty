import {documentFile} from '../../../lib/documents/files';
import type {SupabaseClient} from '@supabase/supabase-js';
import {validId} from './catalog';
import {financeInvoiceEvidence} from './finance-invoice-evidence';
import {financeInvoiceDetail} from './finance-invoice-detail';
async function ownSubmittedInvoice(client:SupabaseClient,owner:string,id:string){const r=await financeInvoiceDetail(client,owner,id);return r?.submitter===owner&&r.state==='submitted'?r:null;}
async function verifiedEvidenceOwner(client:SupabaseClient,owner:string){const r=await client.auth.getUser();if(r.error||r.data.user?.id!==owner||!r.data.user.email_confirmed_at||r.data.user.is_anonymous)throw new Error('Verified invoice account required.');}
export type InvoiceUploadAttempt=Readonly<{invoice_id:string;request_id:string;kind:'invoice'|'supporting';file_name:string;mime_type:string;size:number}>;
export type InvoiceUploadReservation=Readonly<{id:string;state:'uploaded'}|{id:string;state:'reserved';path:string;token:string}>;
export function invoiceUploadAttempt(offer:string,request:string,kind:'invoice'|'supporting',name:string,mime:string,size:number):InvoiceUploadAttempt{
 const file=documentFile(name,mime,size);
 if(!validId(offer)||!validId(request)||!['invoice','supporting'].includes(kind))throw new Error('Choose a valid invoice and upload request.');
 return Object.freeze({invoice_id:offer,request_id:request,kind,file_name:file.name,mime_type:file.mime,size:file.size});
}
function endpoint(base:string){
 const url=new URL(base);if(url.protocol!=='https:'||url.username||url.password||url.search||url.hash||url.pathname!=='/')throw new Error('Secure application connection is not configured.');
 return new URL('/api/native/invoice-evidence',url).toString();
}
async function request(client:SupabaseClient,owner:string,base:string,input:unknown){
 const target=endpoint(base);await verifiedEvidenceOwner(client,owner);
 const session=await client.auth.getSession();
 if(session.error||session.data.session?.user.id!==owner||!session.data.session.access_token)throw new Error('Account session unavailable.');
 const response=await fetch(target,{method:'POST',redirect:'error',headers:{'Content-Type':'application/json',Authorization:`Bearer ${session.data.session.access_token}`},body:JSON.stringify(input)});
 if(!response.ok)throw new Error('Upload could not be confirmed. Keep the same request and check document records.');
 const data=await response.json();await verifiedEvidenceOwner(client,owner);return data;
}
export async function reserveInvoiceUpload(client:SupabaseClient,owner:string,base:string,attempt:InvoiceUploadAttempt):Promise<InvoiceUploadReservation>{
 const checked=invoiceUploadAttempt(attempt.invoice_id,attempt.request_id,attempt.kind,attempt.file_name,attempt.mime_type,attempt.size);
 if(!await ownSubmittedInvoice(client,owner,checked.invoice_id))throw new Error('Own submitted invoice required.');
 const data=await request(client,owner,base,{action:'reserve',...checked});
 if(!data||!validId(data.id))throw new Error('Invalid upload reservation.');
 if(data.state==='uploaded')return Object.freeze({id:data.id,state:'uploaded'});
 if(data.state!=='reserved'||data.path!==checked.invoice_id+'/'+data.id+(checked.mime_type==='application/pdf'?'.pdf':checked.mime_type==='image/jpeg'?'.jpg':'.png')||typeof data.token!=='string'||!data.token)throw new Error('Invalid upload reservation.');
 return Object.freeze({id:data.id,state:'reserved',path:data.path,token:data.token});
}
export async function uploadInvoiceBytes(client:SupabaseClient,owner:string,reservation:InvoiceUploadReservation,attempt:InvoiceUploadAttempt,bytes:ArrayBuffer){
 if(reservation.state!=='reserved'||bytes.byteLength!==attempt.size)throw new Error('Selected file does not match the reservation.');
 await verifiedEvidenceOwner(client,owner);if(!await ownSubmittedInvoice(client,owner,attempt.invoice_id))throw new Error('Own submitted invoice required.');
 const result=await client.storage.from('vendor-invoice-evidence').uploadToSignedUrl(reservation.path,reservation.token,bytes,{contentType:attempt.mime_type,upsert:false});
 if(result.error)throw new Error('Storage upload could not be confirmed. Check or finalize this reservation before uploading again.');
 await verifiedEvidenceOwner(client,owner);
}
export async function finishInvoiceUpload(client:SupabaseClient,owner:string,base:string,offer:string,id:string){
 if(!validId(id))throw new Error('Invalid document.');
 if(!await ownSubmittedInvoice(client,owner,offer))throw new Error('Own submitted invoice required.');
 const row=await client.from('vendor_invoice_evidence').select('id').eq('id',id).eq('invoice_id',offer).eq('user_id',owner).maybeSingle();if(row.error||row.data?.id!==id)throw new Error('Own invoice document required.');
 const data=await request(client,owner,base,{action:'finish',id});
 if(!data||data.state!=='uploaded')throw new Error('Document certification could not be confirmed.');
 const evidence=await financeInvoiceEvidence(client,owner,offer);if(!evidence.rows.some(file=>file.id===id))throw Error('Certified document could not be verified.');
 return Object.freeze({id,state:'uploaded' as const});
}
