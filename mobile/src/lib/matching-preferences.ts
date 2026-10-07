import type {SupabaseClient} from '@supabase/supabase-js';
import type {WorkingPreferences} from './realtors';
import {validId} from './catalog';
import {verifiedSaveOwner} from './saves';
import {EnquiryFailure} from './enquiries';
export function workingPreferences(raw:unknown):WorkingPreferences{
 if(!raw||typeof raw!=='object'||Array.isArray(raw))throw new EnquiryFailure('Check your working preferences.',false);const r=raw as Record<string,unknown>;
 if(['intent','communication_style','guidance_style','decision_pace'].some(k=>typeof r[k]!=='string')||!['buy','rent','sell'].includes(String(r.intent))||!['thoughtful','direct','collaborative'].includes(String(r.communication_style))||!['step-by-step','data-led','independent'].includes(String(r.guidance_style))||!['considered','decisive','flexible'].includes(String(r.decision_pace))||typeof r.preferred_area!=='string'||r.preferred_area.length>120||!r.preferred_area.trim())throw new EnquiryFailure('Check your working preferences.',false);
 return {intent:String(r.intent),preferred_area:r.preferred_area.trim(),communication_style:String(r.communication_style),guidance_style:String(r.guidance_style),decision_pace:String(r.decision_pace)};
}
export async function storedPreferences(client:SupabaseClient,owner:string){
 await verifiedSaveOwner(client,owner);
 const result=await client.from('realtor_match_preferences').select('intent,preferred_area,communication_style,guidance_style,decision_pace,revision').eq('user_id',owner).maybeSingle();
 if(result.error||result.data===undefined)throw new Error('Unable to check stored preferences.');
 let stored:null|{preferences:WorkingPreferences;revision:string}=null;
 if(result.data!==null){if(!validId(result.data.revision))throw new Error('Invalid preference revision.');stored={preferences:workingPreferences(result.data),revision:result.data.revision};}
 await verifiedSaveOwner(client,owner);return stored;
}
export async function changePreferences(client:SupabaseClient,owner:string,input:{action:'save'|'delete';revision:string|null;preferences:unknown;consent:boolean}){
 if(!['save','delete'].includes(input.action)||(input.revision!==null&&!validId(input.revision))||(input.action==='save'&&input.consent!==true))throw new EnquiryFailure('Choose whether to save your preferences first.',false);
 const preferences=input.action==='save'?workingPreferences(input.preferences):null;
 try{await verifiedSaveOwner(client,owner);}catch{throw new EnquiryFailure('Verify your account to manage preferences.',false);}
 let result;try{result=await client.rpc('manage_matching_preferences',{p_action:input.action,p_expected_revision:input.revision,p_preferences:preferences,p_consent:input.action==='save'});}catch{throw new EnquiryFailure('The update could not be confirmed. Check stored preferences before trying again.',true);}
 if(result.error){if(['40001','42501','22023','22P02'].includes(result.error.code))throw new EnquiryFailure('Preferences may have changed. Check your stored preferences and consent.',false);throw new EnquiryFailure('The update could not be confirmed. Check stored preferences before trying again.',true);}
 const response=result.data;
 if(!response||typeof response!=='object'||Array.isArray(response)||(input.action==='save'?response.status!=='saved'||!validId(response.revision):response.status!=='deleted'||response.revision!==null))throw new EnquiryFailure('The update could not be confirmed. Check stored preferences before trying again.',true);
 try{
  const stored=await storedPreferences(client,owner);
  if(input.action==='delete'?stored!==null:!stored||stored.revision!==response.revision||Object.keys(preferences!).some(k=>stored.preferences[k as keyof WorkingPreferences]!==preferences![k as keyof WorkingPreferences]))throw new Error('Changed preferences');
  return stored;
 }catch{throw new EnquiryFailure('Preferences changed while confirming. Check stored preferences before another update.',true);}
}
