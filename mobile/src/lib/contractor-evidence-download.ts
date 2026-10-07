import type {SupabaseClient} from '@supabase/supabase-js';
import {contractorWorkOffer} from './work-offers';
import {validId} from './catalog';
export async function contractorEvidenceDownload(client:SupabaseClient,owner:string,offer:string,id:string){
 if(!validId(id)||!await contractorWorkOffer(client,owner,offer))throw new Error('Assigned contractor evidence required.');
 const read=async()=>{const r=await client.from('contractor_evidence').select('id,offer_id,user_id,state,object_path,file_name').eq('id',id).eq('offer_id',offer).eq('user_id',owner).eq('state','uploaded').maybeSingle();const d=r.data;if(r.error||!d||d.id!==id||d.offer_id!==offer||d.user_id!==owner||d.state!=='uploaded'||typeof d.object_path!=='string'||!d.object_path||d.object_path.length>1024||typeof d.file_name!=='string'||!d.file_name.trim()||d.file_name.length>255)throw new Error('Evidence unavailable.');return {path:d.object_path,name:d.file_name};};
 const doc=await read();const signed=await client.storage.from('contractor-evidence').createSignedUrl(doc.path,120,{download:doc.name});if(signed.error||typeof signed.data?.signedUrl!=='string')throw new Error('Private link unavailable.');
 const url=new URL(signed.data.signedUrl);if(url.protocol!=='https:'||url.hostname!=='zikxzkbfxgdilykyyswt.supabase.co'||url.port||url.username||url.password||url.hash||decodeURIComponent(url.pathname)!=='/storage/v1/object/sign/contractor-evidence/'+doc.path||!url.searchParams.get('token'))throw new Error('Invalid private evidence link.');
 const current=await read();if(current.path!==doc.path||current.name!==doc.name||!await contractorWorkOffer(client,owner,offer))throw new Error('Evidence access changed.');return url.toString();
}
