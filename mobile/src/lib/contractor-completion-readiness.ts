import type {SupabaseClient} from '@supabase/supabase-js';
import {contractorWorkOffer} from './work-offers';
export async function contractorCompletionReadiness(client:SupabaseClient,owner:string,offerId:string){
 const offer=await contractorWorkOffer(client,owner,offerId);if(!offer)throw new Error('Assignment unavailable.');
 const count=async(query:PromiseLike<{count:number|null;error:unknown}>)=>{const r=await query;if(r.error||!Number.isSafeInteger(r.count)||r.count!<0)throw new Error('Completion readiness unavailable.');return r.count!;};
 const presence=(state:string)=>client.from('contractor_presence').select('id,contractor_visits!inner(offer_id)',{head:true,count:'exact'}).eq('contractor_user_id',owner).eq('contractor_visits.offer_id',offerId).eq('state',state);
 const evidence=(state:string)=>client.from('contractor_evidence').select('id',{head:true,count:'exact'}).eq('offer_id',offerId).eq('user_id',owner).eq('state',state);
 const [pending,onSite,departures,proposed,uploaded,reserved]=await Promise.all([
 count(client.from('contractor_completion_reports').select('id',{head:true,count:'exact'}).eq('offer_id',offerId).eq('contractor_user_id',owner).eq('state','submitted')),
 count(presence('on_site')),count(presence('exited')),
 count(client.from('contractor_visits').select('id',{head:true,count:'exact'}).eq('offer_id',offerId).eq('contractor_user_id',owner).eq('state','proposed')),
 count(evidence('uploaded')),count(evidence('reserved'))]);
 const current=await contractorWorkOffer(client,owner,offerId);if(!current||current.version!==offer.version)throw new Error('Assignment changed. Refresh to check.');
 // This is a display precheck. The RPC additionally verifies the work revision,
 // every confirmed visit's departure and frozen evidence under its locks.
 return {offer:current,pending,onSite,departures,proposed,uploaded,reserved,canPrepare:current.state==='accepted'&&pending===0&&onSite===0&&departures>0&&proposed===0};
}
