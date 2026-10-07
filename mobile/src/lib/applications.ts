import type {SupabaseClient} from '@supabase/supabase-js';
import {EnquiryFailure} from './enquiries';
import {validId} from './catalog';
import {verifiedSaveOwner} from './saves';
export const applicationStates=['submitted','under_review','needs_info','approved','rejected','withdrawn','leased'] as const;
export type OwnedApplication={id:string;listing_id:string;title_snapshot:string;status:typeof applicationStates[number];created_at:string};
export async function ownedApplications(client:SupabaseClient,owner:string,inputPage:number){
 await verifiedSaveOwner(client,owner);
 const count=await client.from('rental_applications').select('id',{head:true,count:'exact'}).eq('user_id',owner);
 if(count.error||!Number.isSafeInteger(count.count)||count.count!<0)throw new Error('Unable to count your applications.');
 const total=count.count!,pages=Math.max(1,Math.ceil(total/25)),page=Math.min(Math.max(1,Number.isSafeInteger(inputPage)?inputPage:1),pages);
 let rows:OwnedApplication[]=[];
 if(total){
  const result=await client.from('rental_applications').select('id,listing_id,title_snapshot,status,created_at').eq('user_id',owner).order('created_at',{ascending:false}).order('id',{ascending:true}).range((page-1)*25,page*25-1);
  if(result.error||!Array.isArray(result.data)||result.data.length>25)throw new Error('Unable to load your applications.');
  rows=result.data.map(r=>{
   if(!validId(r.id)||!validId(r.listing_id)||!applicationStates.includes(r.status)||typeof r.title_snapshot!=='string'||!r.title_snapshot.trim()||typeof r.created_at!=='string'||!Number.isFinite(Date.parse(r.created_at)))throw new Error('Invalid application response.');
   return {id:r.id,listing_id:r.listing_id,title_snapshot:r.title_snapshot,status:r.status,created_at:r.created_at};
  });
  if(new Set(rows.map(r=>r.id)).size!==rows.length)throw new Error('Invalid enquiry response.');
 }
 await verifiedSaveOwner(client,owner);return {total,pages,page,rows};
}
export type ApplicationAttempt=Readonly<{requestId:string;listingId:string;name:string;phone:string;householdSize:number;moveIn:string;message:string;consent:true}>;
export function applicationAttempt(raw:{requestId:unknown;listingId:unknown;name:unknown;phone:unknown;householdSize:unknown;moveIn:unknown;message:unknown;consent:unknown}):ApplicationAttempt{
 const text=(v:unknown,min:number,max:number)=>{if(typeof v!=='string'||v.length>max||v.trim().length<min)throw new EnquiryFailure('Check application details.',false);return v.trim();};
 if(!validId(raw.requestId)||!validId(raw.listingId)||raw.consent!==true||typeof raw.householdSize!=='number'||!Number.isInteger(raw.householdSize)||raw.householdSize<1||raw.householdSize>20)throw new EnquiryFailure('Check property, household size and consent.',false);
 const moveIn=text(raw.moveIn,10,10);if(!/^\d{4}-\d{2}-\d{2}$/.test(moveIn))throw new EnquiryFailure('Use a valid YYYY-MM-DD move-in date.',false);const date=new Date(moveIn+'T00:00:00Z');if(!Number.isFinite(date.getTime())||date.toISOString().slice(0,10)!==moveIn)throw new EnquiryFailure('Use a valid move-in date.',false);
 return Object.freeze({requestId:raw.requestId,listingId:raw.listingId,name:text(raw.name,2,120),phone:text(raw.phone,0,40),householdSize:raw.householdSize,moveIn,message:text(raw.message,10,2000),consent:true});
}
export async function submitApplication(client:SupabaseClient,owner:string,attempt:ApplicationAttempt){
 let input:ApplicationAttempt;try{input=applicationAttempt(attempt);}catch{throw new EnquiryFailure('Check your application details and consent.',false);}
 try{await verifiedSaveOwner(client,owner);}catch{throw new EnquiryFailure('Verify your account before applying.',false);}
 let result;try{result=await client.rpc('submit_rental_application',{p_request_id:input.requestId,p_listing_id:input.listingId,p_enquiry_id:null,p_contact_name:input.name,p_phone:input.phone,p_household_size:input.householdSize,p_desired_move_in:input.moveIn,p_message:input.message,p_consent:true});}catch{throw new EnquiryFailure('Application could not be confirmed. Retry the same request or check your applications.',true);}
 if(result.error){if(['42501','22023','22P02','40001','23505','P0001'].includes(result.error.code))throw new EnquiryFailure('Review your applications and check the property, dates and details before applying again.',false);throw new EnquiryFailure('Application could not be confirmed. Retry the same request.',true);}
 if(!validId(result.data))throw new EnquiryFailure('Application could not be confirmed. Retry the same request.',true);
 try{const stored=await client.from('rental_applications').select('id,status').eq('id',result.data).eq('user_id',owner).maybeSingle();if(stored.error||!stored.data||stored.data.id!==result.data||!applicationStates.includes(stored.data.status))throw new Error('Invalid confirmation');await verifiedSaveOwner(client,owner);return {id:result.data,status:stored.data.status as OwnedApplication['status']};}catch{throw new EnquiryFailure('Application may be stored. Check your applications or retry the same request.',true);}
}
export async function applicationDetail(client:SupabaseClient,owner:string,id:string,inputPage:number){
 if(!validId(id))throw new Error('Invalid application reference.');await verifiedSaveOwner(client,owner);
 const result=await client.from('rental_applications').select('id,listing_id,title_snapshot,status,version,household_size,desired_move_in,message,created_at').eq('id',id).eq('user_id',owner).maybeSingle();
 if(result.error)throw new Error('Unable to load application.');
 if(result.data===null){await verifiedSaveOwner(client,owner);return null;}
 const r=result.data;
 if(!r||r.id!==id||!validId(r.listing_id)||!applicationStates.includes(r.status)||typeof r.title_snapshot!=='string'||!Number.isSafeInteger(r.version)||r.version<1||!Number.isInteger(r.household_size)||r.household_size<1||r.household_size>20||typeof r.message!=='string'||typeof r.desired_move_in!=='string'||!/^\d{4}-\d{2}-\d{2}$/.test(r.desired_move_in)||!Number.isFinite(Date.parse(r.created_at)))throw new Error('Invalid application response.');
 const count=await client.from('rental_application_events').select('id',{head:true,count:'exact'}).eq('application_id',id);
 if(count.error||!Number.isSafeInteger(count.count)||count.count!<0)throw new Error('Unable to count shared history.');
 const total=count.count!,pages=Math.max(1,Math.ceil(total/25)),page=Math.min(Math.max(1,Number.isSafeInteger(inputPage)?inputPage:1),pages);
 let events:{id:string;status:OwnedApplication['status'];message:string;created_at:string}[]=[];
 if(total){const history=await client.from('rental_application_events').select('id,new_status,message,created_at').eq('application_id',id).order('created_at',{ascending:false}).order('id',{ascending:true}).range((page-1)*25,page*25-1);if(history.error||!Array.isArray(history.data)||history.data.length>25)throw new Error('Unable to load shared history.');events=history.data.map(e=>{if(!validId(e.id)||!applicationStates.includes(e.new_status)||typeof e.message!=='string'||typeof e.created_at!=='string'||!Number.isFinite(Date.parse(e.created_at)))throw new Error('Invalid history response.');return {id:e.id,status:e.new_status,message:e.message,created_at:e.created_at};});if(new Set(events.map(e=>e.id)).size!==events.length)throw new Error('Invalid history response.');}
 await verifiedSaveOwner(client,owner);return {application:{id:r.id,listing_id:r.listing_id,title:r.title_snapshot,status:r.status as OwnedApplication['status'],version:r.version as number,household_size:r.household_size as number,move_in:r.desired_move_in,message:r.message},events,total,pages,page};
}
export type ApplicationAction=Readonly<{id:string;requestId:string;version:number;action:'reply'|'withdraw';message:string}>;
export function applicationAction(raw:ApplicationAction):ApplicationAction{
 if(!validId(raw.id)||!validId(raw.requestId)||!Number.isInteger(raw.version)||raw.version<1||raw.version>=2147483647||!['reply','withdraw'].includes(raw.action)||typeof raw.message!=='string'||raw.message.trim().length<5||raw.message.length>2000)throw new EnquiryFailure('Check the application action and shared reason.',false);
 return Object.freeze({...raw,message:raw.message.trim()});
}
export async function transitionApplication(client:SupabaseClient,owner:string,attempt:ApplicationAction){
 const input=applicationAction(attempt);try{await verifiedSaveOwner(client,owner);}catch{throw new EnquiryFailure('Verify your account before updating an application.',false);}
 // An applicant can also be staff; enforce ownership before the role-aware RPC.
 try{const owned=await client.from('rental_applications').select('id').eq('id',input.id).eq('user_id',owner).maybeSingle();if(owned.error)throw new Error('Unavailable');if(!owned.data||owned.data.id!==input.id)throw new EnquiryFailure('Application ownership could not be confirmed.',false);}catch(error){if(error instanceof EnquiryFailure)throw error;throw new EnquiryFailure('Application access could not be checked. Try again.',false);}
 let result;try{result=await client.rpc('transition_rental_application',{p_id:input.id,p_request_id:input.requestId,p_expected_version:input.version,p_action:input.action,p_message:input.message});}catch{throw new EnquiryFailure('Update could not be confirmed. Retry the same update.',true);}
 if(result.error){if(['42501','22023','22P02','40001','23505','P0001'].includes(result.error.code))throw new EnquiryFailure('Application changed or this action is unavailable. Refresh before another update.',false);throw new EnquiryFailure('Update could not be confirmed. Retry the same update.',true);}
 const r=result.data;if(!r||!applicationStates.includes(r.status)||!Number.isInteger(r.version)||r.version<input.version+1)throw new EnquiryFailure('Update could not be confirmed. Retry the same update.',true);
 try{const stored=await client.from('rental_applications').select('id,status,version').eq('id',input.id).eq('user_id',owner).maybeSingle();if(stored.error||!stored.data||stored.data.id!==input.id||stored.data.status!==r.status||stored.data.version!==r.version)throw new Error('Changed confirmation');await verifiedSaveOwner(client,owner);return {status:r.status as OwnedApplication['status'],version:r.version as number};}catch{throw new EnquiryFailure('Update may be stored. Check shared history or retry the same update.',true);}
}
