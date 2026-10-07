import {documentFile} from '../../../lib/documents/files';
import type {SupabaseClient} from '@supabase/supabase-js';
import {validId} from './catalog';
import {contractorWorkOffer} from './work-offers';
async function verifiedEvidenceOwner(client:SupabaseClient,owner:string){const r=await client.auth.getUser();if(r.error||r.data.user?.id!==owner||!r.data.user.email_confirmed_at||r.data.user.is_anonymous)throw new Error('Verified contractor account required.');}
export type EvidenceAttempt=Readonly<{offer_id:string;request_id:string;file_name:string;mime_type:string;size:number}>;
export type EvidenceReservation=Readonly<{id:string;state:'uploaded'}|{id:string;state:'reserved';path:string;token:string}>;
export function evidenceAttempt(offer:string,request:string,name:string,mime:string,size:number):EvidenceAttempt{
 const file=documentFile(name,mime,size);
 if(!validId(offer)||!validId(request))throw new Error('Choose a valid assignment and upload request.');
 return Object.freeze({offer_id:offer,request_id:request,file_name:file.name,mime_type:file.mime,size:file.size});
}
function endpoint(base:string){
 const url=new URL(base);if(url.protocol!=='https:'||url.username||url.password||url.search||url.hash||url.pathname!=='/')throw new Error('Secure application connection is not configured.');
 return new URL('/api/native/contractor-evidence',url).toString();
}
async function request(client:SupabaseClient,owner:string,base:string,input:unknown){
 const target=endpoint(base);await verifiedEvidenceOwner(client,owner);
 const session=await client.auth.getSession();
 if(session.error||session.data.session?.user.id!==owner||!session.data.session.access_token)throw new Error('Account session unavailable.');
 const response=await fetch(target,{method:'POST',redirect:'error',headers:{'Content-Type':'application/json',Authorization:`Bearer ${session.data.session.access_token}`},body:JSON.stringify(input)});
 if(!response.ok)throw new Error('Upload could not be confirmed. Keep the same request and check document records.');
 const data=await response.json();await verifiedEvidenceOwner(client,owner);return data;
}
export async function reserveEvidence(client:SupabaseClient,owner:string,base:string,attempt:EvidenceAttempt):Promise<EvidenceReservation>{
 const checked=evidenceAttempt(attempt.offer_id,attempt.request_id,attempt.file_name,attempt.mime_type,attempt.size);
 if(!await contractorWorkOffer(client,owner,checked.offer_id))throw new Error('Active assignment required.');
 const data=await request(client,owner,base,{action:'reserve',...checked});
 if(!data||!validId(data.id))throw new Error('Invalid upload reservation.');
 if(data.state==='uploaded')return Object.freeze({id:data.id,state:'uploaded'});
 if(data.state!=='reserved'||typeof data.path!=='string'||!data.path||typeof data.token!=='string'||!data.token)throw new Error('Invalid upload reservation.');
 return Object.freeze({id:data.id,state:'reserved',path:data.path,token:data.token});
}
export async function uploadEvidenceBytes(client:SupabaseClient,owner:string,reservation:EvidenceReservation,attempt:EvidenceAttempt,bytes:ArrayBuffer){
 if(reservation.state!=='reserved'||bytes.byteLength!==attempt.size)throw new Error('Selected file does not match the reservation.');
 await verifiedEvidenceOwner(client,owner);if(!await contractorWorkOffer(client,owner,attempt.offer_id))throw new Error('Active assignment required.');
 const result=await client.storage.from('contractor-evidence').uploadToSignedUrl(reservation.path,reservation.token,bytes,{contentType:attempt.mime_type,upsert:false});
 if(result.error)throw new Error('Storage upload could not be confirmed. Check or finalize this reservation before uploading again.');
 await verifiedEvidenceOwner(client,owner);
}
export async function finishEvidence(client:SupabaseClient,owner:string,base:string,offer:string,id:string){
 if(!validId(id))throw new Error('Invalid document.');
 if(!await contractorWorkOffer(client,owner,offer))throw new Error('Active assignment required.');
 const row=await client.from('contractor_evidence').select('id').eq('id',id).eq('offer_id',offer).eq('user_id',owner).maybeSingle();if(row.error||row.data?.id!==id)throw new Error('Assigned evidence required.');
 const data=await request(client,owner,base,{action:'finish',id});
 if(!data||data.id!==id||data.state!=='uploaded')throw new Error('Document certification could not be confirmed.');
 return Object.freeze({id,state:'uploaded' as const});
}
