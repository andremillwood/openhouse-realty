export function contractorInput(value:unknown){
 if(!value||typeof value!=='object'||Array.isArray(value))throw new Error('Invalid contractor request.');const input=value as Record<string,unknown>,uuid=/^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
 if(typeof input.request_id!=='string'||!uuid.test(input.request_id)||!(input.account_id===null||typeof input.account_id==='string'&&uuid.test(input.account_id)))throw new Error('Check the contractor reference.');
 if(typeof input.version!=='number'||!Number.isInteger(input.version)||input.version<0||input.version>=2147483647)throw new Error('Refresh the contractor revision.');
 if(typeof input.company_name!=='string'||input.company_name.trim().length<2||input.company_name.length>160)throw new Error('Provide the approved contractor or company name.');
 if(!Array.isArray(input.trade_coverage)||input.trade_coverage.length<1||input.trade_coverage.length>20||input.trade_coverage.some(item=>typeof item!=='string'||!item.trim()||item.length>80))throw new Error('Provide up to 20 approved trades.');
 if(typeof input.is_active!=='boolean'||input.approved!==true||typeof input.reason!=='string'||input.reason.trim().length<5||input.reason.length>500)throw new Error('Record approval and a change reason.');
 let email=null;
 if(input.account_id===null){if(input.version!==0||!input.is_active||typeof input.email!=='string'||input.email.length>254||! /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(input.email.trim()))throw new Error('New registrations need an approved verified email.');email=input.email.trim().toLowerCase();}
 else if(input.version<1)throw new Error('Current contractor revision required.');
 return {p_request_id:input.request_id,p_account_id:input.account_id as string|null,p_expected_version:input.version,p_email:email,p_company_name:input.company_name.trim(),p_trade_coverage:[...new Set((input.trade_coverage as string[]).map(item=>item.trim()))],p_is_active:input.is_active,p_reason:input.reason.trim(),p_approved:true};
}
