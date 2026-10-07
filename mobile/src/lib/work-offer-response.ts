import type {SupabaseClient} from '@supabase/supabase-js';
import {workOfferInput} from '../../../lib/staff/work-offer-validation';
import {contractorWorkOffer} from './work-offers';
import {EnquiryFailure} from './enquiries';
export type WorkOfferAttempt=Readonly<{offer_id:string;request_id:string;version:number;action:'accept'|'decline'|'release';reason:string}>;
export function workOfferAttempt(value:WorkOfferAttempt):WorkOfferAttempt{const r=workOfferInput(value);if(!['accept','decline','release'].includes(r.p_action))throw new EnquiryFailure('Contractor response required.',false);return Object.freeze({offer_id:r.p_offer_id!,request_id:r.p_request_id,version:r.p_expected_offer_version,action:r.p_action as WorkOfferAttempt['action'],reason:r.p_reason});}
export async function respondToWorkOffer(client:SupabaseClient,owner:string,attempt:WorkOfferAttempt){
 let input:WorkOfferAttempt;try{input=workOfferAttempt(attempt);if(!await contractorWorkOffer(client,owner,input.offer_id))throw Error();}catch{throw new EnquiryFailure('Verify your active contractor access before responding.',false);}
 let result;try{result=await client.rpc('manage_contractor_work_offer',workOfferInput(input));}catch{throw new EnquiryFailure('Offer response could not be confirmed. Retry the same request.',true);}
 if(result.error)throw new EnquiryFailure('Offer response could not be confirmed. Refresh or retry the same request.',!['42501','22023','22P02','40001','23505'].includes(result.error.code));
 const r=result.data,expected=input.action==='accept'?'accepted':input.action==='decline'?'declined':'withdrawn';
 try{if(!r||r.id!==input.offer_id||r.version!==input.version+1||![expected,'expired'].includes(r.state))throw Error();
  const current=await contractorWorkOffer(client,owner,input.offer_id);if(!current||current.version<r.version||(current.version===r.version&&current.state!==r.state))throw Error();
  return {id:input.offer_id,version:r.version as number,state:r.state as string,currentVersion:current.version,currentState:current.state};
 }catch{throw new EnquiryFailure('Recorded offer response could not be confirmed. Retry the same request.',true);}
}
