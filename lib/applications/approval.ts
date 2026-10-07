import {uuidPattern} from '@/lib/enquiries/validation';
import {documentKinds} from '@/lib/documents/files';
export type ApprovalPolicy={version:number;required_document_kinds:string[];required_cosigners:number;approver_roles:string[];policy_reference:string};
export function approvalInput(value:unknown){
 if(!value||typeof value!=='object'||Array.isArray(value))throw new Error('Invalid approval request.');const input=value as Record<string,unknown>;
 const id=(key:string)=>{if(typeof input[key]!=='string'||!uuidPattern.test(input[key] as string))throw new Error('Invalid reference.');return input[key] as string;};
 const version=(key:string,min:number)=>{const n=input[key];if(typeof n!=='number'||!Number.isInteger(n)||n<min||n>=2147483647)throw new Error('Invalid version.');return n;};
 const text=(key:string,max:number)=>{const raw=input[key];if(typeof raw!=='string'||raw.trim().length<5||raw.length>max)throw new Error('Record the approved policy/evidence reference and decision reason.');return raw.trim();};
 if(input.action==='policy'){
  const kinds=input.document_kinds,roles=input.approver_roles,count=input.cosigners;
  if(!Array.isArray(kinds)||kinds.length>4||!kinds.every(kind=>documentKinds.includes(kind))||new Set(kinds).size!==kinds.length||!Array.isArray(roles)||!roles.length||roles.length>3||!roles.every(role=>['admin','realtor','manager'].includes(role))||new Set(roles).size!==roles.length||typeof count!=='number'||!Number.isInteger(count)||count<0||count>2||input.approved!==true)throw new Error('Confirm an approved business policy with valid document, co-signer and approver requirements.');
  return {name:'configure_rental_approval_policy',args:{p_request_id:id('request_id'),p_expected_version:version('version',0),p_document_kinds:kinds,p_cosigners:count,p_approver_roles:roles,p_reference:text('reference',500),p_approved:true}};
 }
 if(input.action!=='approve'||input.eligibility_checked!==true||input.availability_checked!==true)throw new Error('Complete eligibility and property checks before approval.');
 return {name:'approve_rental_application',args:{p_application_id:id('application_id'),p_request_id:id('request_id'),p_expected_version:version('version',1),p_policy_version:version('policy_version',1),p_reason:text('reason',2000),p_evidence_reference:text('evidence_reference',500),p_eligibility_checked:true,p_availability_checked:true}};
}
