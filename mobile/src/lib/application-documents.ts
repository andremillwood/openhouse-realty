import type {SupabaseClient} from '@supabase/supabase-js';
import {validId} from './catalog';
import {verifiedSaveOwner} from './saves';
export async function applicationDocuments(client:SupabaseClient,owner:string,application:string,pageInput:number){
 if(!validId(application))throw new Error('Invalid application.');await verifiedSaveOwner(client,owner);
 const owned=await client.from('rental_applications').select('id').eq('id',application).eq('user_id',owner).maybeSingle();
 if(owned.error||!owned.data||owned.data.id!==application)throw new Error('Application ownership required.');
 const count=await client.from('application_documents').select('id',{head:true,count:'exact'}).eq('application_id',application).eq('state','uploaded');
 if(count.error||!Number.isSafeInteger(count.count)||count.count!<0)throw new Error('Unable to count documents.');
 const total=count.count!,pages=Math.max(1,Math.ceil(total/25)),page=Math.min(Math.max(1,Number.isSafeInteger(pageInput)?pageInput:1),pages);
 let rows:{id:string;file_name:string;kind:string;created_at:string}[]=[];
 if(total){const result=await client.from('application_documents').select('id,file_name,kind,created_at').eq('application_id',application).eq('state','uploaded').order('created_at',{ascending:false}).order('id',{ascending:true}).range((page-1)*25,page*25-1);if(result.error||!Array.isArray(result.data)||result.data.length>25)throw new Error('Unable to load documents.');rows=result.data.map(r=>{if(!validId(r.id)||typeof r.file_name!=='string'||!r.file_name||typeof r.kind!=='string'||!r.kind||typeof r.created_at!=='string'||!Number.isFinite(Date.parse(r.created_at)))throw new Error('Invalid document response.');return {id:r.id,file_name:r.file_name,kind:r.kind,created_at:r.created_at};});if(new Set(rows.map(r=>r.id)).size!==rows.length)throw new Error('Invalid document response.');}
 await verifiedSaveOwner(client,owner);return {total,pages,page,rows};
}
export async function applicationDocumentReservations(client:SupabaseClient,owner:string,application:string,pageInput:number){
 if(!validId(application))throw new Error('Invalid application.');await verifiedSaveOwner(client,owner);
 const owned=await client.from('rental_applications').select('id').eq('id',application).eq('user_id',owner).maybeSingle();
 if(owned.error||!owned.data||owned.data.id!==application)throw new Error('Application ownership required.');
 const count=await client.from('application_documents').select('id',{head:true,count:'exact'}).eq('application_id',application).eq('user_id',owner).eq('state','reserved');
 if(count.error||!Number.isSafeInteger(count.count)||count.count!<0)throw new Error('Unable to count documents.');
 const total=count.count!,pages=Math.max(1,Math.ceil(total/25)),page=Math.min(Math.max(1,Number.isSafeInteger(pageInput)?pageInput:1),pages);
 let rows:{id:string;file_name:string;kind:string;created_at:string;expires_at:string}[]=[];
 if(total){const result=await client.from('application_documents').select('id,file_name,kind,created_at,expires_at').eq('application_id',application).eq('user_id',owner).eq('state','reserved').order('created_at',{ascending:false}).order('id',{ascending:true}).range((page-1)*25,page*25-1);if(result.error||!Array.isArray(result.data)||result.data.length>25)throw new Error('Unable to load documents.');rows=result.data.map(r=>{if(!validId(r.id)||typeof r.file_name!=='string'||!r.file_name||!['identity','income','reference','other'].includes(r.kind)||typeof r.created_at!=='string'||!Number.isFinite(Date.parse(r.created_at))||typeof r.expires_at!=='string'||!Number.isFinite(Date.parse(r.expires_at)))throw new Error('Invalid document response.');return {id:r.id,file_name:r.file_name,kind:r.kind,created_at:r.created_at,expires_at:r.expires_at};});if(new Set(rows.map(r=>r.id)).size!==rows.length)throw new Error('Invalid document response.');}
 await verifiedSaveOwner(client,owner);return {total,pages,page,rows};
}
export async function applicationDocumentDownload(client:SupabaseClient,owner:string,application:string,id:string){
 if(!validId(application)||!validId(id))throw new Error('Invalid document.');await verifiedSaveOwner(client,owner);
 const owned=await client.from('rental_applications').select('id').eq('id',application).eq('user_id',owner).maybeSingle();
 if(owned.error||!owned.data||owned.data.id!==application)throw new Error('Application ownership required.');
 const doc=await client.from('application_documents').select('id,object_path,file_name').eq('id',id).eq('application_id',application).eq('user_id',owner).eq('state','uploaded').maybeSingle();
 if(doc.error||!doc.data||doc.data.id!==id||typeof doc.data.object_path!=='string'||!doc.data.object_path||typeof doc.data.file_name!=='string'||!doc.data.file_name)throw new Error('Document unavailable.');
 const result=await client.storage.from('application-documents').createSignedUrl(doc.data.object_path,120,{download:doc.data.file_name});
 if(result.error||!result.data||typeof result.data.signedUrl!=='string')throw new Error('Unable to prepare download.');
 const url=new URL(result.data.signedUrl);if(url.protocol!=='https:'||url.hostname!=='zikxzkbfxgdilykyyswt.supabase.co'||url.username||url.password||!url.pathname.startsWith('/storage/v1/object/sign/application-documents/')||!url.searchParams.get('token'))throw new Error('Invalid document download.');
 await verifiedSaveOwner(client,owner);return url.toString();
}
export async function withdrawApplicationDocument(client:SupabaseClient,owner:string,application:string,id:string){
 if(!validId(application)||!validId(id))throw new Error('Invalid document.');await verifiedSaveOwner(client,owner);
 const owned=await client.from('rental_applications').select('id').eq('id',application).eq('user_id',owner).maybeSingle();
 if(owned.error||!owned.data||owned.data.id!==application)throw new Error('Application ownership required.');
 const doc=await client.from('application_documents').select('id,state').eq('id',id).eq('application_id',application).eq('user_id',owner).maybeSingle();
 if(doc.error||!doc.data||doc.data.id!==id)throw new Error('Document unavailable.');
 const result=await client.rpc('withdraw_application_document',{p_document_id:id});if(result.error)throw new Error('Withdrawal could not be confirmed.');
 const stored=await client.from('application_documents').select('id,state').eq('id',id).eq('application_id',application).eq('user_id',owner).maybeSingle();
 if(stored.error||!stored.data||stored.data.id!==id||stored.data.state!=='withdrawn')throw new Error('Withdrawal could not be confirmed.');
 await verifiedSaveOwner(client,owner);return 'withdrawn' as const;
}
