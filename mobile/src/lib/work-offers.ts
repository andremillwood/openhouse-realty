import type {SupabaseClient} from '@supabase/supabase-js';
import {validId} from './catalog';
const offerStates=['offered','accepted','declined','withdrawn','expired','completed'] as const;
export type OfferState=typeof offerStates[number];
export function offerState(value:unknown):OfferState|''{return typeof value==='string'&&offerStates.includes(value as OfferState)?value as OfferState:'';}
async function verifiedContractor(client:SupabaseClient,owner:string){const r=await client.auth.getUser();if(r.error||r.data.user?.id!==owner||!r.data.user.email_confirmed_at||r.data.user.is_anonymous)throw new Error('Verified contractor account required.');}
async function registrations(client:SupabaseClient,owner:string){
 const count=await client.from('contractor_accounts').select('id',{head:true,count:'exact'}).eq('user_id',owner).eq('is_active',true);
 if(count.error||!Number.isSafeInteger(count.count)||count.count!<0||count.count!>10000)throw new Error('Contractor registrations unavailable.');
 const ids:string[]=[];for(let offset=0;offset<count.count!;offset+=100){const r=await client.from('contractor_accounts').select('id').eq('user_id',owner).eq('is_active',true).order('id',{ascending:true}).range(offset,Math.min(offset+99,count.count!-1));if(r.error||!Array.isArray(r.data)||r.data.length!==Math.min(100,count.count!-offset))throw new Error('Contractor access changed. Refresh to check.');for(const row of r.data){if(!validId(row.id)||ids.includes(row.id))throw new Error('Invalid contractor registration.');ids.push(row.id);}}
 return ids;
}
export async function contractorWorkOffers(client:SupabaseClient,owner:string,pageInput:number,stateInput:unknown){
 await verifiedContractor(client,owner);const ids=await registrations(client,owner),state=offerState(stateInput);
 if(!ids.length){await verifiedContractor(client,owner);return {registered:false,total:0,page:1,pages:1,state,rows:[] as {id:string;title:string;trade:string;state:OfferState;expires:string;expired:boolean}[]};}
 const query=(head=false)=>{let q=client.from('contractor_work_offers').select('id,job_title,trade,state,expires_at',{head,count:'exact'}).in('contractor_id',ids);if(state)q=q.eq('state',state);return q;};
 const count=await query(true);if(count.error||!Number.isSafeInteger(count.count)||count.count!<0)throw new Error('Work offers unavailable.');const total=count.count!,pages=Math.max(1,Math.ceil(total/25)),page=Math.min(Math.max(1,Number.isSafeInteger(pageInput)?pageInput:1),pages);
 const r=total?await query().order('created_at',{ascending:false}).order('id',{ascending:true}).range((page-1)*25,page*25-1):{data:[],error:null};
 if(r.error||!Array.isArray(r.data)||r.data.length>25)throw new Error('Work offers unavailable.');
 const rows=r.data.map(row=>{if(!validId(row.id)||!offerStates.includes(row.state)||typeof row.job_title!=='string'||!row.job_title.trim()||row.job_title.length>500||typeof row.trade!=='string'||!row.trade.trim()||row.trade.length>100||typeof row.expires_at!=='string'||!Number.isFinite(Date.parse(row.expires_at))||(state&&row.state!==state))throw new Error('Invalid work offer.');return {id:row.id,title:row.job_title,trade:row.trade,state:row.state as OfferState,expires:row.expires_at,expired:row.state==='offered'&&Date.parse(row.expires_at)<=Date.now()};});if(new Set(rows.map(row=>row.id)).size!==rows.length)throw new Error('Invalid work offers.');
 await verifiedContractor(client,owner);const current=await registrations(client,owner);if(current.length!==ids.length||current.some((id,i)=>id!==ids[i]))throw new Error('Contractor access changed. Refresh to check.');
 await verifiedContractor(client,owner);return {registered:true,total,page,pages,state,rows};
}
export async function contractorWorkOffer(client:SupabaseClient,owner:string,id:string){
 if(!validId(id))throw new Error('Invalid offer reference.');await verifiedContractor(client,owner);const ids=await registrations(client,owner);if(!ids.length)throw new Error('Active contractor registration required.');
 const response=await client.from('contractor_work_offers').select('id,contractor_id,job_title,scope_summary,trade,company_name_snapshot,state,version,expires_at').eq('id',id).in('contractor_id',ids).maybeSingle();if(response.error)throw new Error('Work offer unavailable.');const r=response.data;if(!r){await verifiedContractor(client,owner);return null;}
 if(r.id!==id||!ids.includes(r.contractor_id)||!offerStates.includes(r.state)||!Number.isInteger(r.version)||r.version<1||r.version>=2147483647||typeof r.expires_at!=='string'||!Number.isFinite(Date.parse(r.expires_at))||(['job_title','scope_summary','trade','company_name_snapshot'] as const).some(k=>typeof r[k]!=='string'||!r[k].trim()||r[k].length>3000))throw new Error('Invalid work offer.');
 const current=await registrations(client,owner);if(!current.includes(r.contractor_id))throw new Error('Contractor access changed.');await verifiedContractor(client,owner);
 return {id:r.id as string,title:r.job_title as string,scope:r.scope_summary as string,trade:r.trade as string,company:r.company_name_snapshot as string,state:r.state as OfferState,version:r.version as number,expires:r.expires_at as string,expired:r.state==='offered'&&Date.parse(r.expires_at)<=Date.now()};
}
