import type {SupabaseClient} from '@supabase/supabase-js';
import {validId} from './catalog';
import type {RealtorProfile} from '../../../lib/discovery/realtor-matching';
export {rankRealtors} from '../../../lib/discovery/realtor-matching';
export type {RealtorProfile,WorkingPreferences} from '../../../lib/discovery/realtor-matching';
export const realtorProjection='id,display_name,bio,photo_url,service_areas,supported_intents,communication_style,guidance_style,decision_pace';
export function publicRealtor(raw:unknown):RealtorProfile{
 if(!raw||typeof raw!=='object'||Array.isArray(raw))throw new Error('Invalid realtor response.');const r=raw as Record<string,unknown>;
 if(!validId(r.id)||typeof r.display_name!=='string'||!r.display_name.trim()||typeof r.bio!=='string'||!['thoughtful','direct','collaborative'].includes(String(r.communication_style))||!['step-by-step','data-led','independent'].includes(String(r.guidance_style))||!['considered','decisive','flexible'].includes(String(r.decision_pace)))throw new Error('Invalid realtor response.');
 const list=(value:unknown,allowed?:string[])=>{if(!Array.isArray(value)||!value.length||value.length>100||value.some(v=>typeof v!=='string'||!v.trim()||(allowed&&!allowed.includes(v)))||new Set(value).size!==value.length)throw new Error('Invalid realtor response.');return value as string[];};
 if(r.photo_url!==null&&typeof r.photo_url!=='string')throw new Error('Invalid realtor response.');let photo:string|null=null;
 if(r.photo_url){try{const url=new URL(String(r.photo_url));if(url.protocol==='https:'&&!url.username&&!url.password)photo=url.toString();}catch{}}
 return {id:r.id,display_name:r.display_name,bio:r.bio,photo_url:photo,service_areas:list(r.service_areas),supported_intents:list(r.supported_intents,['buy','rent','sell']),communication_style:String(r.communication_style),guidance_style:String(r.guidance_style),decision_pace:String(r.decision_pace)};
}
export async function publishedRealtors(client:SupabaseClient){
 const result=await client.from('realtor_profiles').select(realtorProjection).eq('is_published',true).order('display_name',{ascending:true}).order('id',{ascending:true}).limit(201);
 if(result.error||!Array.isArray(result.data)||result.data.length>200)throw new Error('The directory could not be loaded completely. Please contact the team.');
 const rows=result.data.map(publicRealtor);if(new Set(rows.map(r=>r.id)).size!==rows.length)throw new Error('Invalid realtor response.');return rows;
}
