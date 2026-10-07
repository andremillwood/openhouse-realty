import {uuidPattern} from '@/lib/enquiries/validation';
import {jamaicaToday} from '@/lib/applications/validation';
/** Parse configured money exactly; never use floating-point arithmetic for posting. */
export function jmdMinorUnits(value:unknown):string{
 if(typeof value!=='string'||!/^\d{1,12}(?:\.\d{1,2})?$/.test(value))throw new Error('Enter a nonnegative JMD amount with at most two decimal places.');
 const [whole,fraction='']=value.split('.');return (BigInt(whole)*100n+BigInt(fraction.padEnd(2,'0'))).toString();
}
export function leasePreparationInput(value:unknown,now=new Date()){
 if(!value||typeof value!=='object'||Array.isArray(value))throw new Error('Invalid lease preparation request.');const input=value as Record<string,unknown>;
 const uuid=(key:string)=>{const raw=input[key];if(typeof raw!=='string'||!uuidPattern.test(raw))throw new Error('Valid application, template and request references required.');return raw;};
 const revision=(key:string)=>{const raw=input[key];if(typeof raw!=='number'||!Number.isInteger(raw)||raw<1||raw>=2147483647)throw new Error('Use the current application and approved template versions.');return raw;};
 const date=(key:string)=>{const raw=input[key];if(typeof raw!=='string'||!/^\d{4}-\d{2}-\d{2}$/.test(raw))throw new Error('Choose valid lease dates.');try{if(new Date(`${raw}T00:00:00Z`).toISOString().slice(0,10)!==raw)throw new Error();}catch{throw new Error('Choose valid lease dates.');}return raw;};
 const draftVersion=input.draft_version;if(typeof draftVersion!=='number'||!Number.isInteger(draftVersion)||draftVersion<0||draftVersion>=2147483647)throw new Error('Use the current lease draft version.');
 const start=date('starts_on'),end=date('ends_on');if(start<jamaicaToday(now)||end<=start)throw new Error('Lease end must follow its start, and a new lease cannot start in the past.');
 const billingDay=input.billing_day;if(typeof billingDay!=='number'||!Number.isInteger(billingDay)||billingDay<1||billingDay>31)throw new Error('Choose a monthly billing day between 1 and 31.');
 if(input.terms_approved!==true)throw new Error('Approved lease terms are required.');
 const reference=input.approval_reference;if(typeof reference!=='string'||reference.trim().length<5||reference.length>500)throw new Error('Record the approved terms reference.');
 // Applicant, property/unit, rent and participants are derived from approved records.
 return {p_application_id:uuid('application_id'),p_request_id:uuid('request_id'),p_expected_application_version:revision('application_version'),p_expected_draft_version:draftVersion,p_template_id:uuid('template_id'),p_template_version:revision('template_version'),p_starts_on:start,p_ends_on:end,p_billing_day:billingDay,p_deposit_minor:jmdMinorUnits(input.deposit_jmd),p_approval_reference:reference.trim(),p_terms_approved:true};
}
export function leaseTemplateInput(value:unknown){
 if(!value||typeof value!=='object'||Array.isArray(value))throw new Error('Invalid template registration.');const input=value as Record<string,unknown>;
 if(typeof input.request_id!=='string'||!uuidPattern.test(input.request_id)||typeof input.template_key!=='string'||!/^[a-z][a-z0-9_-]{2,63}$/.test(input.template_key)||typeof input.version!=='number'||!Number.isInteger(input.version)||input.version<0||input.version>=2147483647||typeof input.title!=='string'||input.title.trim().length<3||input.title.length>160||typeof input.source_reference!=='string'||input.source_reference.trim().length<5||input.source_reference.length>500||typeof input.sha256!=='string'||!/^[a-f0-9]{64}$/i.test(input.sha256)||input.business_approved!==true)throw new Error('Record a valid template key, current version, approved source reference and SHA-256 fingerprint.');
 return {p_request_id:input.request_id,p_key:input.template_key,p_expected_version:input.version,p_title:input.title.trim(),p_source_reference:input.source_reference.trim(),p_sha256:input.sha256.toLowerCase(),p_business_approved:true};
}
