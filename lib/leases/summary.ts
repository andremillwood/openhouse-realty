import {uuidPattern} from '@/lib/enquiries/validation';
export function leaseSummaryReleaseInput(value:unknown){
 if(!value||typeof value!=='object'||Array.isArray(value))throw new Error('Check the summary release.');
 const input=value as Record<string,unknown>;
 for(const key of ['application_id','draft_id','request_id'])if(typeof input[key]!=='string'||!uuidPattern.test(input[key] as string))throw new Error('Valid application, draft and request references required.');
 if(typeof input.version!=='number'||!Number.isInteger(input.version)||input.version<1||input.version>=2147483647)throw new Error('Use the current draft version.');
 if(typeof input.release_reference!=='string'||input.release_reference.trim().length<5||input.release_reference.length>500||input.sharing_approved!==true)throw new Error('Record approval to share this summary with the applicant.');
 return {p_application_id:input.application_id as string,p_draft_id:input.draft_id as string,p_request_id:input.request_id as string,p_expected_version:input.version,p_release_reference:input.release_reference.trim(),p_sharing_approved:true};
}
export type ApplicantLeaseSummary={id:string;version:number;state:'prepared'|'superseded'|'voided';starts_on:string;ends_on:string;billing_day:number;rent_minor:string;deposit_minor:string;property_name:string;unit_label:string;template_title:string;released_at:string};
export function applicantLeaseSummaryResult(value:unknown):{total:number;items:ApplicantLeaseSummary[]}{
 if(!value||typeof value!=='object'||Array.isArray(value))throw new Error('Summary unavailable.');const result=value as Record<string,unknown>;
 if(typeof result.total!=='number'||!Number.isSafeInteger(result.total)||result.total<0||!Array.isArray(result.items)||result.items.length>25||result.items.length>result.total)throw new Error('Summary unavailable.');
 const date=(raw:unknown)=>typeof raw==='string'&&/^\d{4}-\d{2}-\d{2}$/.test(raw)&&Number.isFinite(Date.parse(raw+'T00:00:00Z'))&&new Date(raw+'T00:00:00Z').toISOString().slice(0,10)===raw;
 const seen=new Set<string>();let previous=Infinity;
 for(const raw of result.items){
  if(!raw||typeof raw!=='object'||Array.isArray(raw))throw new Error('Summary unavailable.');const item=raw as Record<string,unknown>;
  if(typeof item.id!=='string'||!uuidPattern.test(item.id)||seen.has(item.id)||typeof item.version!=='number'||!Number.isInteger(item.version)||item.version<1||item.version>=previous||!['prepared','superseded','voided'].includes(item.state as string)||!date(item.starts_on)||!date(item.ends_on)||(item.ends_on as string)<=(item.starts_on as string)||typeof item.billing_day!=='number'||!Number.isInteger(item.billing_day)||item.billing_day<1||item.billing_day>31)throw new Error('Summary unavailable.');
  for(const key of ['rent_minor','deposit_minor'])if(typeof item[key]!=='string'||!/^\d{1,14}$/.test(item[key] as string)||(key==='rent_minor'&&BigInt(item[key] as string)<=0n))throw new Error('Summary unavailable.');
  for(const key of ['property_name','unit_label','template_title'])if(typeof item[key]!=='string'||!(item[key] as string).trim()||(item[key] as string).length>500)throw new Error('Summary unavailable.');
  if(typeof item.released_at!=='string'||!Number.isFinite(Date.parse(item.released_at)))throw new Error('Summary unavailable.');seen.add(item.id);previous=item.version;
 }
 return {total:result.total,items:result.items as ApplicantLeaseSummary[]};
}
export function leaseSummaryMoney(value:string){const amount=BigInt(value);return `JMD ${(amount/100n).toLocaleString('en-JM')}.${(amount%100n).toString().padStart(2,'0')}`;}
