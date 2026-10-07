import type {SupabaseClient} from '@supabase/supabase-js';
import {leaseReviewHistory,leaseReviewInput} from '../../../lib/leases/review';
import {EnquiryFailure} from './enquiries';
import {validId} from './catalog';
import {verifiedSaveOwner} from './saves';
export async function applicantLeaseReview(client:SupabaseClient,owner:string,application:string,draft:string,pageInput:number){
 if(!validId(application)||!validId(draft))throw new Error('Invalid summary reference.');
 await verifiedSaveOwner(client,owner);
 const parent=await client.from('rental_applications').select('id').eq('id',application).eq('user_id',owner).maybeSingle();if(parent.error||parent.data?.id!==application)throw new Error('Application ownership required.');
 const requested=Math.min(100000,Math.max(1,Number.isSafeInteger(pageInput)?pageInput:1));
 const read=async(page:number)=>{const response=await client.rpc('lease_summary_review_history',{p_application_id:application,p_draft_id:draft,p_page:page});if(response.error)throw new Error('Summary review unavailable.');const r=leaseReviewHistory(response.data);if(r.role!=='applicant'||r.summary.id!==draft)throw new Error('Applicant summary required.');return r;};
 let r=await read(requested);const page=Math.min(requested,Math.max(1,Math.ceil(r.total/25)));if(page!==requested)r=await read(page);const pages=Math.max(1,Math.ceil(r.total/25));if(page>pages)throw new Error('Review changed. Refresh to check.');
 const s=r.summary,summary={id:s.id,version:s.version,state:s.state,starts_on:s.starts_on,ends_on:s.ends_on,billing_day:s.billing_day,rent_minor:s.rent_minor,deposit_minor:s.deposit_minor,property_name:s.property_name,unit_label:s.unit_label,template_title:s.template_title,released_at:s.released_at};
 const items=r.items.map(e=>({id:e.id,version:e.version,action:e.action,actor_kind:e.actor_kind,message:e.message,created_at:e.created_at}));
 await verifiedSaveOwner(client,owner);return {release:r.release_id,current:r.current,revision:r.revision,latestAction:r.latest_action,total:r.total,page,pages,summary,items};
}

export type ApplicantReviewAttempt=Readonly<{application:string;draft:string;release_id:string;request_id:string;version:number;action:'reviewed'|'question';message:string;review_only_acknowledged:true}>;
export function applicantReviewAttempt(value:ApplicantReviewAttempt):ApplicantReviewAttempt{
 const input=leaseReviewInput(value);if(!validId(value.application)||!validId(value.draft)||input.p_action==='answer')throw new EnquiryFailure('Applicant review or question required.',false);
 return Object.freeze({application:value.application,draft:value.draft,release_id:input.p_release_id,request_id:input.p_request_id,version:input.p_expected_version,action:input.p_action,message:input.p_message,review_only_acknowledged:true});
}
export async function respondToLeaseSummary(client:SupabaseClient,owner:string,attempt:ApplicantReviewAttempt){
 let input:ApplicantReviewAttempt;try{input=applicantReviewAttempt(attempt);const history=await applicantLeaseReview(client,owner,input.application,input.draft,1);if(history.release!==input.release_id)throw Error();}catch{throw new EnquiryFailure('Verify your account and application summary before responding.',false);}
 let response;try{response=await client.rpc('review_rental_lease_summary',leaseReviewInput(input));}catch{throw new EnquiryFailure('Response could not be confirmed. Retry the same request.',true);}
 if(response.error)throw new EnquiryFailure('Response could not be confirmed. Refresh or retry the same request.',!['42501','22023','22P02','40001','23505','P0001'].includes(response.error.code));
 const r=response.data;
 try{
  if(!r||!validId(r.id)||r.release_id!==input.release_id||r.version!==input.version+1||r.action!==input.action)throw Error();
  const stored=await client.from('rental_lease_review_events').select('id,release_id,version,action,actor_kind,message').eq('id',r.id).eq('release_id',input.release_id).maybeSingle();const e=stored.data;
  if(stored.error||!e||e.id!==r.id||e.release_id!==input.release_id||e.version!==r.version||e.action!==input.action||e.actor_kind!=='applicant'||e.message!==input.message)throw Error();
  await verifiedSaveOwner(client,owner);
 }catch{throw new EnquiryFailure('Recorded response could not be confirmed. Retry the same request.',true);}
 return {id:r.id as string,version:r.version as number,action:input.action};
}
