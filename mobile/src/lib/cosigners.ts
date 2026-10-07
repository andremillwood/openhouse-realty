import type {SupabaseClient} from '@supabase/supabase-js';
import {validId} from './catalog';
import {EnquiryFailure} from './enquiries';
export type CosignerDecision=Readonly<{id:string;requestId:string;version:number;action:'accept'|'decline'|'withdraw';consent:boolean}>;
export function cosignerDecision(input:CosignerDecision):CosignerDecision{
 if(!validId(input.id)||!validId(input.requestId)||!Number.isInteger(input.version)||input.version<1||input.version>=2147483647||!['accept','decline','withdraw'].includes(input.action)||typeof input.consent!=='boolean'||input.action==='accept'&&!input.consent)throw new EnquiryFailure('Choose a valid invitation decision and explicitly consent to review participation.',false);
 return Object.freeze({...input,consent:input.action==='accept'});
}
export async function respondToCosigner(client:SupabaseClient,owner:string,attempt:CosignerDecision){
 const input=cosignerDecision(attempt);const email=await recipient(client,owner);
 const access=await client.from('application_cosigners').select('id,applicant_user_id,recipient_user_id,invite_email').eq('id',input.id).maybeSingle();
 if(access.error||!access.data||access.data.applicant_user_id===owner||access.data.recipient_user_id!==owner&&!(access.data.recipient_user_id===null&&access.data.invite_email===email))throw new EnquiryFailure('Invited verified recipient access could not be confirmed.',false);
 let result;try{result=await client.rpc('respond_application_cosigner',{p_id:input.id,p_request_id:input.requestId,p_expected_version:input.version,p_action:input.action,p_consent:input.consent});}catch{throw new EnquiryFailure('Decision could not be confirmed. Retry the same request.',true);}
 if(result.error)throw new EnquiryFailure('Decision could not be confirmed. Refresh or retry the same request.',!['42501','22023','22P02','40001'].includes(result.error.code));
 const r=result.data;if(!r||!states.includes(r.state)||!Number.isInteger(r.version)||r.version<input.version+1||r.version>2147483647)throw new EnquiryFailure('Decision response could not be confirmed.',true);
 try{const stored=await client.from('application_cosigners').select('id,recipient_user_id,state,version').eq('id',input.id).eq('recipient_user_id',owner).maybeSingle();if(stored.error||!stored.data||stored.data.id!==input.id||stored.data.state!==r.state||stored.data.version!==r.version||await recipient(client,owner)!==email)throw Error();}catch{throw new EnquiryFailure('Recorded decision could not be confirmed. Retry the same request.',true);}
 return {state:r.state as string,version:r.version as number};
}
const states=['pending','accepted','declined','revoked','withdrawn'];
export function invitationReference(input:string){
 const trimmed=input.trim();if(validId(trimmed as unknown))return trimmed;
 if(trimmed.length>2048)throw new Error('Invalid invitation link.');
 const url=new URL(trimmed),match=url.pathname.match(/^\/cosigners\/([a-f0-9-]{36})$/i);
 if(url.protocol!=='https:'||url.username||url.password||!match||!validId(match[1]))throw new Error('Invalid invitation link.');
 // Extract an identifier only. Never fetch or navigate to the supplied host.
 return match[1];
}
async function recipient(client:SupabaseClient,owner:string){const r=await client.auth.getUser();if(r.error||r.data.user?.id!==owner||!r.data.user.email_confirmed_at||r.data.user.is_anonymous||!r.data.user.email)throw new Error('Verified invited account required.');return r.data.user.email.toLowerCase();}
export async function cosignerInvitation(client:SupabaseClient,owner:string,id:string,pageInput:number){
 if(!validId(id))throw new Error('Invalid invitation.');const email=await recipient(client,owner);
 const result=await client.from('application_cosigners').select('id,recipient_user_id,invite_email,applicant_name_snapshot,title_snapshot,area_snapshot,rent_jmd_snapshot,state,version,expires_at').eq('id',id).maybeSingle();
 if(result.error)throw new Error('Invitation unavailable.');const r=result.data;
 if(!r){await recipient(client,owner);return null;}
 // RLS also permits staff/applicant previews. Native recipient review must not
 // mistake those previews for consent rights.
 if(r.recipient_user_id!==owner&&!(r.recipient_user_id===null&&r.invite_email===email))throw new Error('Invited recipient required.');
 const price=String(r.rent_jmd_snapshot);
 if(r.id!==id||!states.includes(r.state)||!Number.isInteger(r.version)||r.version<1||r.version>=2147483647||!/^\d{1,12}(\.\d{1,2})?$/.test(price)||Number(price)<=0||typeof r.expires_at!=='string'||!Number.isFinite(Date.parse(r.expires_at))||(['applicant_name_snapshot','title_snapshot','area_snapshot'] as const).some(k=>typeof r[k]!=='string'||!r[k].trim()))throw new Error('Invalid invitation response.');
 if(r.recipient_user_id===null&&(r.state!=='pending'||Date.parse(r.expires_at)<=Date.now()))throw new Error('Invitation is no longer available to claim.');
 const availability=await client.rpc('cosigner_invitation_active',{p_id:id});if(availability.error||typeof availability.data!=='boolean')throw new Error('Invitation availability could not be checked.');
 const count=await client.from('application_cosigner_events').select('id',{count:'exact',head:true}).eq('cosigner_id',id);if(count.error||!Number.isSafeInteger(count.count)||count.count!<0)throw new Error('Invitation history unavailable.');
 const total=count.count!,pages=Math.max(1,Math.ceil(total/25)),page=Math.min(Math.max(1,Number.isSafeInteger(pageInput)?pageInput:1),pages);
 let events:{id:string;event_name:string;new_state:string;created_at:string}[]=[];
 if(total){const history=await client.from('application_cosigner_events').select('id,event_name,new_state,created_at').eq('cosigner_id',id).order('created_at',{ascending:false}).order('id',{ascending:true}).range((page-1)*25,page*25-1);if(history.error||!Array.isArray(history.data)||history.data.length>25)throw new Error('Invitation history unavailable.');events=history.data.map(e=>{if(!validId(e.id)||typeof e.event_name!=='string'||!e.event_name||!states.includes(e.new_state)||typeof e.created_at!=='string'||!Number.isFinite(Date.parse(e.created_at)))throw new Error('Invalid invitation history.');return {id:e.id,event_name:e.event_name,new_state:e.new_state,created_at:e.created_at};});if(new Set(events.map(e=>e.id)).size!==events.length)throw new Error('Invalid invitation history.');}
 if(await recipient(client,owner)!==email)throw new Error('Invited account changed.');
 return {id,applicant:r.applicant_name_snapshot as string,title:r.title_snapshot as string,area:r.area_snapshot as string,rent:price,state:r.state as string,version:r.version as number,expires:r.expires_at as string,active:availability.data,events,total,pages,page};
}
