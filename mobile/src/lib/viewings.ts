import type {SupabaseClient} from '@supabase/supabase-js';
import {validId} from './catalog';
import {verifiedSaveOwner} from './saves';
import {EnquiryFailure} from './enquiries';
export const viewingStates=['requested','confirmed','completed','cancelled','no_show','expired'] as const;
export type ViewingState=typeof viewingStates[number];
export type ViewingAttempt=Readonly<{requestId:string;slotId:string;name:string;phone:string;consent:true}>;
export function viewingAttempt(input:{requestId:unknown;slotId:unknown;name:unknown;phone:unknown;consent:unknown}):ViewingAttempt{
 if(!validId(input.requestId)||!validId(input.slotId)||typeof input.name!=='string'||input.name.trim().length<2||input.name.length>120||typeof input.phone!=='string'||input.phone.length>40||input.consent!==true)throw new EnquiryFailure('Check your viewing time, contact details and consent.',false);
 return Object.freeze({requestId:input.requestId,slotId:input.slotId,name:input.name.trim(),phone:input.phone.trim(),consent:true});
}
export async function requestViewing(client:SupabaseClient,owner:string,attempt:ViewingAttempt){
 const input=viewingAttempt(attempt);try{await verifiedSaveOwner(client,owner);}catch{throw new EnquiryFailure('Verify your account before requesting a viewing.',false);}
 let result;try{result=await client.rpc('request_viewing',{p_request_id:input.requestId,p_slot_id:input.slotId,p_enquiry_id:null,p_contact_name:input.name,p_phone:input.phone,p_consent:true});}catch{throw new EnquiryFailure('Unable to confirm your request. Retry the same viewing request.',true);}
 if(result.error){if(['42501','22023','22P02','P0001','23505','40001','40P01'].includes(result.error.code))throw new EnquiryFailure('This time may be unavailable, overlap an appointment, or exceed your request limit. Check your appointments and refresh availability.',false);throw new EnquiryFailure('Unable to confirm your request. Retry the same viewing request.',true);}
 if(!validId(result.data))throw new EnquiryFailure('Unable to confirm your request. Retry the same viewing request.',true);
 try{
  const stored=await client.from('viewings').select('id,status').eq('id',result.data).eq('user_id',owner).maybeSingle();
  if(stored.error||!stored.data||stored.data.id!==result.data||!viewingStates.includes(stored.data.status))throw new Error('Invalid confirmation');
  await verifiedSaveOwner(client,owner);return {id:result.data,status:stored.data.status as ViewingState};
 }catch{throw new EnquiryFailure('Your request may be stored. Retry the same request or check your appointments.',true);}
}
export type ViewingSlot={id:string;starts_at:string;ends_at:string};
export async function availableViewingSlots(client:SupabaseClient,listing:string,now=Date.now()):Promise<ViewingSlot[]>{
 if(!validId(listing)||!Number.isFinite(now))throw new Error('Invalid property or time.');
 const result=await client.from('viewing_slots').select('id,listing_id,starts_at,ends_at,state,hold_expires_at').eq('listing_id',listing).gt('starts_at',new Date(now+30*60000).toISOString()).or(`state.eq.open,and(state.eq.held,hold_expires_at.lte.${new Date(now).toISOString()})`).order('starts_at',{ascending:true}).order('id',{ascending:true}).limit(20);
 if(result.error||!Array.isArray(result.data)||result.data.length>20)throw new Error('Availability could not be loaded.');
 const rows=result.data.map(r=>{
  const start=Date.parse(r.starts_at),end=Date.parse(r.ends_at);
  if(!validId(r.id)||r.listing_id!==listing||typeof r.starts_at!=='string'||typeof r.ends_at!=='string'||!Number.isFinite(start)||!Number.isFinite(end)||start<=now+30*60000||end-start<15*60000||end-start>120*60000||!(r.state==='open'||(r.state==='held'&&typeof r.hold_expires_at==='string'&&Date.parse(r.hold_expires_at)<=now)))throw new Error('Availability changed. Refresh before choosing a time.');
  return {id:r.id,starts_at:r.starts_at,ends_at:r.ends_at};
 });
 if(new Set(rows.map(r=>r.id)).size!==rows.length)throw new Error('Invalid availability response.');return rows;
}
export type OwnedViewing={id:string;listing_id:string;status:ViewingState;requested_for:string;ends_at:string|null;hold_expires_at:string|null;title_snapshot:string|null;cancellation_reason:string|null};
export async function ownedViewings(client:SupabaseClient,owner:string,inputPage:number){
 await verifiedSaveOwner(client,owner);
 const count=await client.from('viewings').select('id',{head:true,count:'exact'}).eq('user_id',owner);
 if(count.error||!Number.isSafeInteger(count.count)||count.count!<0)throw new Error('Unable to count appointments.');
 const total=count.count!,pages=Math.max(1,Math.ceil(total/25)),page=Math.min(Math.max(1,Number.isSafeInteger(inputPage)?inputPage:1),pages);
 let rows:OwnedViewing[]=[];
 if(total){
  const result=await client.from('viewings').select('id,listing_id,status,requested_for,ends_at,hold_expires_at,title_snapshot,cancellation_reason').eq('user_id',owner).order('created_at',{ascending:false}).order('id',{ascending:true}).range((page-1)*25,page*25-1);
  if(result.error||!Array.isArray(result.data)||result.data.length>25)throw new Error('Unable to load appointments.');
  rows=result.data.map(r=>{
   const time=(v:unknown,nullable=false)=>nullable&&v===null?true:typeof v==='string'&&Number.isFinite(Date.parse(v));
   const text=(v:unknown)=>v===null||typeof v==='string';
   if(!validId(r.id)||!validId(r.listing_id)||!viewingStates.includes(r.status)||!time(r.requested_for)||!time(r.ends_at,true)||!time(r.hold_expires_at,true)||!text(r.title_snapshot)||!text(r.cancellation_reason))throw new Error('Invalid appointment response.');
   return {id:r.id,listing_id:r.listing_id,status:r.status,requested_for:r.requested_for,ends_at:r.ends_at,hold_expires_at:r.hold_expires_at,title_snapshot:r.title_snapshot,cancellation_reason:r.cancellation_reason};
  });
  if(new Set(rows.map(r=>r.id)).size!==rows.length)throw new Error('Invalid appointment response.');
 }
 await verifiedSaveOwner(client,owner);return {total,pages,page,rows,checkedAt:Date.now()};
}
export async function cancelViewing(client:SupabaseClient,owner:string,id:string,reason:string){
 if(!validId(id)||typeof reason!=='string'||reason.trim().length<5||reason.length>500)throw new EnquiryFailure('Provide a cancellation reason of 5 to 500 characters.',false);
 try{await verifiedSaveOwner(client,owner);}catch{throw new EnquiryFailure('Verify your account before cancelling.',false);}
 let result;try{result=await client.rpc('transition_viewing',{p_viewing_id:id,p_action:'cancel',p_reason:reason.trim()});}catch{throw new EnquiryFailure('Cancellation could not be confirmed. Retry the same cancellation.',true);}
 if(result.error){if(['42501','22023','P0001','40001','23505','40P01'].includes(result.error.code))throw new EnquiryFailure('This appointment cannot change now. Refresh its status.',false);throw new EnquiryFailure('Cancellation could not be confirmed. Retry the same cancellation.',true);}
 if(!viewingStates.includes(result.data))throw new EnquiryFailure('Cancellation could not be confirmed. Retry the same cancellation.',true);
 try{const stored=await client.from('viewings').select('id,status').eq('id',id).eq('user_id',owner).maybeSingle();if(stored.error||!stored.data||stored.data.id!==id||stored.data.status!==result.data)throw new Error('Changed confirmation');await verifiedSaveOwner(client,owner);return stored.data.status as ViewingState;}catch{throw new EnquiryFailure('Cancellation could not be confirmed. Check the appointment or retry the same cancellation.',true);}
}
