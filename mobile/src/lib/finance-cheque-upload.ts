import {documentFile} from '../../../lib/documents/files';
import type {SupabaseClient} from '@supabase/supabase-js';
import {validId} from './catalog';
import {financeChequeEvidence} from './finance-cheque-evidence';
import {financeChequeHistory} from './finance-cheque-history';
import {financeChequeDecisions} from './finance-cheque-decisions';
async function accessibleCheque(client:SupabaseClient,owner:string,id:string,kind?:'deposit'|'clearance'|'return'){const r=await financeChequeHistory(client,owner,id);return !kind||financeChequeDecisions(r.cheque.state).some(choice=>choice.kind===kind)?r.cheque:null;}
async function verifiedEvidenceOwner(client:SupabaseClient,owner:string){const r=await client.auth.getUser();if(r.error||r.data.user?.id!==owner||!r.data.user.email_confirmed_at||r.data.user.is_anonymous)throw new Error('Verified cheque account required.');}
export type ChequeUploadAttempt=Readonly<{cheque_id:string;request_id:string;kind:'deposit'|'clearance'|'return';file_name:string;mime_type:string;size:number}>;
export type ChequeUploadReservation=Readonly<{id:string;state:'uploaded'}|{id:string;state:'reserved';path:string;token:string}>;
export function chequeUploadAttempt(offer:string,request:string,kind:'deposit'|'clearance'|'return',name:string,mime:string,size:number):ChequeUploadAttempt{
 const file=documentFile(name,mime,size);
 if(!validId(offer)||!validId(request)||!['deposit','clearance','return'].includes(kind))throw new Error('Choose a valid cheque and upload request.');
 return Object.freeze({cheque_id:offer,request_id:request,kind,file_name:file.name,mime_type:file.mime,size:file.size});
}
function endpoint(base:string){
 const url=new URL(base);if(url.protocol!=='https:'||url.username||url.password||url.search||url.hash||url.pathname!=='/')throw new Error('Secure application connection is not configured.');
 return new URL('/api/native/cheque-evidence',url).toString();
}
async function request(client:SupabaseClient,owner:string,base:string,input:unknown){
 const target=endpoint(base);await verifiedEvidenceOwner(client,owner);
 const session=await client.auth.getSession();
 if(session.error||session.data.session?.user.id!==owner||!session.data.session.access_token)throw new Error('Account session unavailable.');
 const response=await fetch(target,{method:'POST',redirect:'error',headers:{'Content-Type':'application/json',Authorization:`Bearer ${session.data.session.access_token}`},body:JSON.stringify(input)});
 if(!response.ok)throw new Error('Upload could not be confirmed. Keep the same request and check document records.');
 const data=await response.json();await verifiedEvidenceOwner(client,owner);return data;
}
export async function reserveChequeUpload(client:SupabaseClient,owner:string,base:string,attempt:ChequeUploadAttempt):Promise<ChequeUploadReservation>{
 const checked=chequeUploadAttempt(attempt.cheque_id,attempt.request_id,attempt.kind,attempt.file_name,attempt.mime_type,attempt.size);
 if(!await accessibleCheque(client,owner,checked.cheque_id,checked.kind))throw new Error('Verified finance access and an eligible cheque stage required.');
 const data=await request(client,owner,base,{action:'reserve',...checked});
 if(!data||!validId(data.id))throw new Error('Invalid upload reservation.');
 if(data.state==='uploaded')return Object.freeze({id:data.id,state:'uploaded'});
 if(data.state!=='reserved'||data.path!==checked.cheque_id+'/'+data.id+(checked.mime_type==='application/pdf'?'.pdf':checked.mime_type==='image/jpeg'?'.jpg':'.png')||typeof data.token!=='string'||!data.token)throw new Error('Invalid upload reservation.');
 return Object.freeze({id:data.id,state:'reserved',path:data.path,token:data.token});
}
export async function uploadChequeBytes(client:SupabaseClient,owner:string,reservation:ChequeUploadReservation,attempt:ChequeUploadAttempt,bytes:ArrayBuffer){
 const checked=chequeUploadAttempt(attempt.cheque_id,attempt.request_id,attempt.kind,attempt.file_name,attempt.mime_type,attempt.size);
 if(reservation.state!=='reserved'||!validId(reservation.id)||reservation.path!==checked.cheque_id+'/'+reservation.id+(checked.mime_type==='application/pdf'?'.pdf':checked.mime_type==='image/jpeg'?'.jpg':'.png')||typeof reservation.token!=='string'||!reservation.token||bytes.byteLength!==checked.size)throw new Error('Selected file does not match the reservation.');
 await verifiedEvidenceOwner(client,owner);if(!await accessibleCheque(client,owner,attempt.cheque_id,attempt.kind))throw new Error('Verified finance access and an eligible cheque stage required.');
 const result=await client.storage.from('cheque-bank-evidence').uploadToSignedUrl(reservation.path,reservation.token,bytes,{contentType:attempt.mime_type,upsert:false});
 if(result.error)throw new Error('Storage upload could not be confirmed. Check or finalize this reservation before uploading again.');
 await verifiedEvidenceOwner(client,owner);await accessibleCheque(client,owner,attempt.cheque_id);
}
export async function finishChequeUpload(client:SupabaseClient,owner:string,base:string,offer:string,id:string){
 if(!validId(id))throw new Error('Invalid document.');
 if(!await accessibleCheque(client,owner,offer))throw new Error('Verified finance access and an eligible cheque stage required.');
 const row=await client.from('cheque_bank_evidence').select('id').eq('id',id).eq('cheque_id',offer).eq('user_id',owner).maybeSingle();if(row.error||row.data?.id!==id)throw new Error('Own cheque document required.');
 const data=await request(client,owner,base,{action:'finish',id});
 if(!data||data.state!=='uploaded')throw new Error('Document certification could not be confirmed.');
 const evidence=await financeChequeEvidence(client,owner,offer);if(!evidence.rows.some(file=>file.id===id))throw Error('Certified document could not be verified.');
 return Object.freeze({id,state:'uploaded' as const});
}
