import type {SupabaseClient} from '@supabase/supabase-js';
import {contractorWorkOffer} from './work-offers';
import {validId} from './catalog';
export async function contractorVisitHistory(client:SupabaseClient,owner:string,offer:string,pageInput:number){
 if(!await contractorWorkOffer(client,owner,offer))throw new Error('Assigned work offer required.');
 const query=(head=false)=>client.from('contractor_visits').select('id,offer_id,contractor_user_id,state,version,starts_at,ends_at,shared_note',{head,count:'exact'}).eq('offer_id',offer).eq('contractor_user_id',owner);
 const count=await query(true);if(count.error||!Number.isSafeInteger(count.count)||count.count!<0)throw new Error('Appointment history unavailable.');const total=count.count!,pages=Math.max(1,Math.ceil(total/25)),page=Math.min(Math.max(1,Number.isSafeInteger(pageInput)?pageInput:1),pages);
 const response=total?await query().order('created_at',{ascending:false}).order('id',{ascending:true}).range((page-1)*25,page*25-1):{data:[],error:null};if(response.error||!Array.isArray(response.data)||response.data.length>25)throw new Error('Appointment history unavailable.');
 const rows=response.data.map(r=>{const start=Date.parse(r.starts_at),end=Date.parse(r.ends_at);if(!validId(r.id)||r.offer_id!==offer||r.contractor_user_id!==owner||!['proposed','confirmed','declined','cancelled','completed'].includes(r.state)||!Number.isInteger(r.version)||r.version<1||r.version>=2147483647||typeof r.starts_at!=='string'||typeof r.ends_at!=='string'||!Number.isFinite(start)||!Number.isFinite(end)||end<=start||end-start>8*60*60*1000||typeof r.shared_note!=='string'||r.shared_note.length>1000)throw new Error('Invalid appointment history.');return {id:r.id as string,state:r.state as string,version:r.version as number,starts:r.starts_at as string,ends:r.ends_at as string,note:r.shared_note as string};});if(new Set(rows.map(r=>r.id)).size!==rows.length)throw new Error('Invalid appointment history.');
 if(!await contractorWorkOffer(client,owner,offer))throw new Error('Contractor access changed. Refresh to check.');return {total,pages,page,rows};
}
