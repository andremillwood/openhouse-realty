import {uuidPattern} from '@/lib/enquiries/validation';
export function cosignerInput(value:unknown){
 if(!value||typeof value!=='object'||Array.isArray(value))throw new Error('Invalid co-signer request.');const input=value as Record<string,unknown>;
 if(typeof input.request_id!=='string'||!uuidPattern.test(input.request_id))throw new Error('Valid request reference required.');
 if(input.action==='invite'){
  if(typeof input.application_id!=='string'||!uuidPattern.test(input.application_id)||typeof input.email!=='string'||input.email.length>254||!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(input.email.trim())||input.permission!==true)throw new Error('Enter a recipient email and confirm permission to share this invitation.');
  return {name:'invite_application_cosigner',args:{p_application_id:input.application_id,p_request_id:input.request_id,p_email:input.email.trim().toLowerCase(),p_permission:true}};
 }
 if(typeof input.id!=='string'||!uuidPattern.test(input.id)||typeof input.version!=='number'||!Number.isInteger(input.version)||input.version<1||input.version>=2147483647||typeof input.action!=='string'||!['accept','decline','withdraw','revoke'].includes(input.action)||input.action==='accept'&&input.consent!==true)throw new Error('Check the invitation action and explicit review consent.');
 return {name:'respond_application_cosigner',args:{p_id:input.id,p_request_id:input.request_id,p_expected_version:input.version,p_action:input.action,p_consent:input.action==='accept'}};
}
