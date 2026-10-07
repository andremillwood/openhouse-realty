import type {SupabaseClient} from '@supabase/supabase-js';
import {validId} from './catalog';
import {verifiedSaveOwner} from './saves';
import {EnquiryFailure} from './enquiries';
export type CosignerInvite=Readonly<{application:string;requestId:string;email:string;permission:true}>;
export type CosignerRevocation=Readonly<{application:string;id:string;requestId:string;version:number}>;
export function cosignerRevocation(input:CosignerRevocation):CosignerRevocation{
 if(!validId(input.application)||!validId(input.id)||!validId(input.requestId)||!Number.isInteger(input.version)||input.version<1||input.version>=2147483647)throw new EnquiryFailure('Refresh the invitation before revoking it.',false);return Object.freeze({...input});
}
export async function revokeCosigner(client:SupabaseClient,owner:string,attempt:CosignerRevocation){
 const input=cosignerRevocation(attempt);
 try{await verifiedSaveOwner(client,owner);const parent=await client.from('rental_applications').select('id').eq('id',input.application).eq('user_id',owner).maybeSingle();if(parent.error||parent.data?.id!==input.application)throw Error();const invitation=await client.from('application_cosigners').select('id').eq('id',input.id).eq('application_id',input.application).eq('applicant_user_id',owner).maybeSingle();if(invitation.error||invitation.data?.id!==input.id)throw Error();}catch{throw new EnquiryFailure('Owned invitation access could not be confirmed.',false);}
 let result;try{result=await client.rpc('respond_application_cosigner',{p_id:input.id,p_request_id:input.requestId,p_expected_version:input.version,p_action:'revoke',p_consent:false});}catch{throw new EnquiryFailure('Revocation could not be confirmed. Retry the same request.',true);}
 if(result.error)throw new EnquiryFailure('Revocation could not be confirmed. Refresh the invitation.',!['42501','22023','22P02','40001'].includes(result.error.code));
 const r=result.data;if(!r||r.state!=='revoked'||!Number.isInteger(r.version)||r.version<input.version+1||r.version>2147483647)throw new EnquiryFailure('Revocation response could not be confirmed.',true);
 try{const stored=await client.from('application_cosigners').select('id,state,version').eq('id',input.id).eq('application_id',input.application).eq('applicant_user_id',owner).maybeSingle();if(stored.error||stored.data?.id!==input.id||stored.data.state!==r.state||stored.data.version!==r.version)throw Error();await verifiedSaveOwner(client,owner);}catch{throw new EnquiryFailure('Recorded revocation could not be confirmed. Retry the same request.',true);}
 return {state:'revoked' as const,version:r.version as number};
}
export function cosignerInvite(application:string,requestId:string,email:string,permission:boolean):CosignerInvite{
 const normalized=email.trim().toLowerCase();if(!validId(application)||!validId(requestId)||!permission||normalized.length>254||!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(normalized))throw new EnquiryFailure('Enter a recipient email and confirm sharing permission.',false);
 return Object.freeze({application,requestId,email:normalized,permission:true});
}
export async function inviteCosigner(client:SupabaseClient,owner:string,attempt:CosignerInvite){
 const input=cosignerInvite(attempt.application,attempt.requestId,attempt.email,attempt.permission);
 try{await verifiedSaveOwner(client,owner);const parent=await client.from('rental_applications').select('id').eq('id',input.application).eq('user_id',owner).maybeSingle();if(parent.error||parent.data?.id!==input.application)throw Error();}catch{throw new EnquiryFailure('Your application access could not be confirmed.',false);}
 let result;try{result=await client.rpc('invite_application_cosigner',{p_application_id:input.application,p_request_id:input.requestId,p_email:input.email,p_permission:true});}catch{throw new EnquiryFailure('Invitation could not be confirmed. Retry the same request.',true);}
 if(result.error)throw new EnquiryFailure('Invitation could not be confirmed. Check the application stage and invitation limits.',!['42501','22023','22P02','P0001'].includes(result.error.code));
 if(!validId(result.data))throw new EnquiryFailure('Invitation response could not be confirmed.',true);
 try{const stored=await client.from('application_cosigners').select('id,invite_email,state,version,request_id').eq('id',result.data).eq('application_id',input.application).eq('applicant_user_id',owner).maybeSingle();const r=stored.data;if(stored.error||!r||r.id!==result.data||r.request_id!==input.requestId||r.invite_email!==input.email||!['pending','accepted','declined','revoked','withdrawn'].includes(r.state)||!Number.isInteger(r.version)||r.version<1||r.version>2147483647)throw Error();await verifiedSaveOwner(client,owner);return {id:r.id,state:r.state as string,version:r.version as number};}catch{throw new EnquiryFailure('Recorded invitation could not be confirmed. Retry the same request.',true);}
}
export async function applicationCosigners(client:SupabaseClient,owner:string,application:string,pageInput:number){
 if(!validId(application))throw new Error('Invalid application.');await verifiedSaveOwner(client,owner);
 const parent=await client.from('rental_applications').select('id').eq('id',application).eq('user_id',owner).maybeSingle();if(parent.error||parent.data?.id!==application)throw new Error('Application ownership required.');
 const count=await client.from('application_cosigners').select('id',{head:true,count:'exact'}).eq('application_id',application).eq('applicant_user_id',owner);if(count.error||!Number.isSafeInteger(count.count)||count.count!<0)throw new Error('Invitation count unavailable.');
 const total=count.count!,pages=Math.max(1,Math.ceil(total/25)),page=Math.min(Math.max(1,Number.isSafeInteger(pageInput)?pageInput:1),pages);
 let rows:{id:string;email:string;state:string;version:number;expires:string;created:string}[]=[];
 if(total){const result=await client.from('application_cosigners').select('id,invite_email,state,version,expires_at,created_at').eq('application_id',application).eq('applicant_user_id',owner).order('created_at',{ascending:false}).order('id',{ascending:true}).range((page-1)*25,page*25-1);if(result.error||!Array.isArray(result.data)||result.data.length>25)throw new Error('Invitations unavailable.');
  rows=result.data.map(r=>{if(!validId(r.id)||typeof r.invite_email!=='string'||r.invite_email.length>254||!/^\S+@\S+\.\S+$/.test(r.invite_email)||!['pending','accepted','declined','revoked','withdrawn'].includes(r.state)||!Number.isInteger(r.version)||r.version<1||r.version>2147483647||typeof r.expires_at!=='string'||!Number.isFinite(Date.parse(r.expires_at))||typeof r.created_at!=='string'||!Number.isFinite(Date.parse(r.created_at)))throw new Error('Invalid invitation record.');return {id:r.id,email:r.invite_email,state:r.state,version:r.version,expires:r.expires_at,created:r.created_at};});if(new Set(rows.map(r=>r.id)).size!==rows.length)throw new Error('Invalid invitation records.');
 }
 await verifiedSaveOwner(client,owner);return {total,pages,page,rows};
}
