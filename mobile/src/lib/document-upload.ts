import type {SupabaseClient} from '@supabase/supabase-js';
import {validId} from './catalog';
import {verifiedSaveOwner} from './saves';
import {documentFile,documentKinds} from '../../../lib/documents/files';
export type DocumentAttempt=Readonly<{application_id:string;request_id:string;kind:typeof documentKinds[number];file_name:string;mime_type:string;size:number}>;
export type DocumentReservation=Readonly<{id:string;state:'uploaded'}|{id:string;state:'reserved';path:string;token:string}>;
export function documentAttempt(application:string,request:string,kind:typeof documentKinds[number],name:string,mime:string,size:number):DocumentAttempt{
 const file=documentFile(name,mime,size);
 if(!validId(application)||!validId(request)||!documentKinds.includes(kind))throw new Error('Choose a document category for this application.');
 return Object.freeze({application_id:application,request_id:request,kind,file_name:file.name,mime_type:file.mime,size:file.size});
}
function endpoint(base:string){
 const url=new URL(base);if(url.protocol!=='https:'||url.username||url.password||url.search||url.hash||url.pathname!=='/')throw new Error('Secure application connection is not configured.');
 return new URL('/api/native/documents',url).toString();
}
async function request(client:SupabaseClient,owner:string,base:string,input:unknown){
 const target=endpoint(base);await verifiedSaveOwner(client,owner);
 const session=await client.auth.getSession();
 if(session.error||session.data.session?.user.id!==owner||!session.data.session.access_token)throw new Error('Account session unavailable.');
 const response=await fetch(target,{method:'POST',redirect:'error',headers:{'Content-Type':'application/json',Authorization:`Bearer ${session.data.session.access_token}`},body:JSON.stringify(input)});
 if(!response.ok)throw new Error('Upload could not be confirmed. Keep the same request and check document records.');
 const data=await response.json();await verifiedSaveOwner(client,owner);return data;
}
export async function reserveDocument(client:SupabaseClient,owner:string,base:string,attempt:DocumentAttempt):Promise<DocumentReservation>{
 const checked=documentAttempt(attempt.application_id,attempt.request_id,attempt.kind,attempt.file_name,attempt.mime_type,attempt.size);
 const data=await request(client,owner,base,{action:'reserve',...checked});
 if(!data||!validId(data.id))throw new Error('Invalid upload reservation.');
 if(data.state==='uploaded')return Object.freeze({id:data.id,state:'uploaded'});
 if(data.state!=='reserved'||typeof data.path!=='string'||!data.path||typeof data.token!=='string'||!data.token)throw new Error('Invalid upload reservation.');
 return Object.freeze({id:data.id,state:'reserved',path:data.path,token:data.token});
}
export async function uploadDocumentBytes(client:SupabaseClient,owner:string,reservation:DocumentReservation,attempt:DocumentAttempt,bytes:ArrayBuffer){
 if(reservation.state!=='reserved'||bytes.byteLength!==attempt.size)throw new Error('Selected file does not match the reservation.');
 await verifiedSaveOwner(client,owner);
 const result=await client.storage.from('application-documents').uploadToSignedUrl(reservation.path,reservation.token,bytes,{contentType:attempt.mime_type,upsert:false});
 if(result.error)throw new Error('Storage upload could not be confirmed. Check or finalize this reservation before uploading again.');
 await verifiedSaveOwner(client,owner);
}
export async function finishDocument(client:SupabaseClient,owner:string,base:string,id:string){
 if(!validId(id))throw new Error('Invalid document.');
 const data=await request(client,owner,base,{action:'finish',id});
 if(!data||data.id!==id||data.state!=='uploaded')throw new Error('Document certification could not be confirmed.');
 return Object.freeze({id,state:'uploaded' as const});
}
