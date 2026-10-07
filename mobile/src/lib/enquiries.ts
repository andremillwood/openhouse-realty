import type {SupabaseClient} from '@supabase/supabase-js';
import {validId} from './catalog';
import {verifiedSaveOwner} from './saves';
export type EnquiryAttempt=Readonly<{requestId:string;listingId:string|null;realtorId:string|null;name:string;phone:string;message:string;consent:true}>;
export class EnquiryFailure extends Error {
 constructor(message:string,public readonly uncertain:boolean){super(message);}
}
export function enquiryAttempt(input:{requestId:unknown;listingId?:unknown;realtorId?:unknown;name:unknown;phone:unknown;message:unknown;consent:unknown}):EnquiryAttempt{
 const text=(value:unknown,min:number,max:number)=>{if(typeof value!=='string'||value.length>max||value.trim().length<min)throw new EnquiryFailure('Check your contact details and message.',false);return value.trim();};
 const listing=input.listingId??null,realtor=input.realtorId??null;
 if(!validId(input.requestId)||(listing===null)===(realtor===null)||(listing!==null&&!validId(listing))||(realtor!==null&&!validId(realtor))||input.consent!==true)throw new EnquiryFailure('Choose one property or realtor and consent to contact.',false);
 return Object.freeze({requestId:input.requestId,listingId:listing as string|null,realtorId:realtor as string|null,name:text(input.name,2,120),phone:text(input.phone,0,40),message:text(input.message,10,4000),consent:true});
}
export async function submitEnquiry(client:SupabaseClient,owner:string,attempt:EnquiryAttempt){
 const input=enquiryAttempt(attempt);
 try{await verifiedSaveOwner(client,owner);}catch{throw new EnquiryFailure('Verify your account before contacting the team.',false);}
 let result;
 try{result=await client.rpc('submit_enquiry',{p_request_id:input.requestId,p_listing_id:input.listingId,p_realtor_id:input.realtorId,p_contact_name:input.name,p_phone:input.phone,p_message:input.message,p_consent:true});}
 catch{throw new EnquiryFailure('Your enquiry could not be confirmed. Retry the same request.',true);}
 if(result.error){
  const code=result.error.code;
  if(code==='P0001')throw new EnquiryFailure('You have reached the enquiry limit. Try again later.',false);
  if(code==='42501')throw new EnquiryFailure('Verify your account before contacting the team.',false);
  if(['22023','22P02'].includes(code))throw new EnquiryFailure('Check your details. This property may be unavailable.',false);
  throw new EnquiryFailure('Your enquiry could not be confirmed. Retry the same request.',true);
 }
 if(!validId(result.data))throw new EnquiryFailure('Your enquiry could not be confirmed. Retry the same request.',true);
 try{await verifiedSaveOwner(client,owner);}catch{throw new EnquiryFailure('Account changed while confirming. Return to the original account and retry the same request.',true);}
 return result.data;
}
export type StoredEnquiry={id:string;status:'new'|'contacted'|'closed';message:string;created_at:string;listing_id:string|null;realtor_id:string|null};
export async function ownedEnquiries(client:SupabaseClient,owner:string,inputPage:number){
 await verifiedSaveOwner(client,owner);
 const count=await client.from('enquiries').select('id',{head:true,count:'exact'}).eq('user_id',owner);
 if(count.error||!Number.isSafeInteger(count.count)||count.count!<0)throw new Error('Unable to count your enquiries.');
 const total=count.count!,pages=Math.max(1,Math.ceil(total/25)),page=Math.min(Math.max(1,Number.isSafeInteger(inputPage)?inputPage:1),pages);
 let rows:StoredEnquiry[]=[];
 if(total){
  const result=await client.from('enquiries').select('id,status,message,created_at,listing_id,realtor_id').eq('user_id',owner).order('created_at',{ascending:false}).order('id',{ascending:true}).range((page-1)*25,page*25-1);
  if(result.error||!Array.isArray(result.data)||result.data.length>25)throw new Error('Unable to load your enquiries.');
  rows=result.data.map(r=>{
   if(!validId(r.id)||!['new','contacted','closed'].includes(r.status)||typeof r.message!=='string'||typeof r.created_at!=='string'||!Number.isFinite(Date.parse(r.created_at))||!((r.listing_id===null&&validId(r.realtor_id))||(r.realtor_id===null&&validId(r.listing_id))))throw new Error('Invalid enquiry response.');
   return {id:r.id,status:r.status,message:r.message,created_at:r.created_at,listing_id:r.listing_id,realtor_id:r.realtor_id};
  });
  if(new Set(rows.map(r=>r.id)).size!==rows.length)throw new Error('Invalid enquiry response.');
 }
 await verifiedSaveOwner(client,owner);return {total,pages,page,rows};
}
