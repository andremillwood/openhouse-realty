export function membershipInput(value:unknown){
 if(!value||typeof value!=='object'||Array.isArray(value))throw new Error('Invalid membership request.');const input=value as Record<string,unknown>;
 const uuid=/^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
 if(typeof input.request_id!=='string'||!uuid.test(input.request_id)||!(input.revision===null||typeof input.revision==='string'&&uuid.test(input.revision)))throw new Error('Refresh the membership revision.');
 if(typeof input.email!=='string'||input.email.length>254||! /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(input.email.trim()))throw new Error('Provide the approved account email.');
 if(!(input.role===null||typeof input.role==='string'&&['admin','realtor','manager','finance'].includes(input.role)))throw new Error('Choose an available role or revoke access.');
 if(typeof input.reason!=='string'||input.reason.trim().length<5||input.reason.length>500||input.approved!==true)throw new Error('Record approval and a change reason.');
 return {p_request_id:input.request_id,p_email:input.email.trim().toLowerCase(),p_role:input.role as string|null,p_expected_revision:input.revision as string|null,p_reason:input.reason.trim(),p_approved:true};
}
