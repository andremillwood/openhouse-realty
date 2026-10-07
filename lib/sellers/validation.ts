import { uuidPattern } from '@/lib/enquiries/validation';
export const sellerStages = ['new','contacted','market_review','proposal','listed','closed','lost'] as const;
export function sellerInput(value:unknown){
 if(!value||typeof value!=='object'||Array.isArray(value))throw new Error('Invalid seller request.');
 const input=value as Record<string,unknown>;
 const text=(key:string,min:number,max:number)=>{const v=input[key];if(typeof v!=='string'||v.trim().length<min||v.length>max)throw new Error(`Check ${key.replaceAll('_',' ')}.`);return v.trim();};
 const requestId=text('request_id',36,36),realtorId=text('realtor_id',36,36);if(!uuidPattern.test(requestId)||!uuidPattern.test(realtorId))throw new Error('Choose an available sales realtor.');
 const type=text('property_type',1,20),intent=text('seller_intent',1,30);
 if(!['house','apartment','land','commercial','other'].includes(type)||!['curious','considering','soon','already_listed'].includes(intent))throw new Error('Check the property type and timing.');
 if(input.consent!==true)throw new Error('Consent is required for team follow-up.');
 return {p_request_id:requestId,p_realtor_id:realtorId,p_name:text('name',2,120),p_phone:text('phone',0,40),p_property_address:text('property_address',5,300),p_area:text('area',2,120),p_property_type:type,p_seller_intent:intent,p_message:text('message',10,2000),p_consent:true};
}
export function sellerTransition(value:unknown){
 if(!value||typeof value!=='object')throw new Error('Invalid follow-up.');const input=value as Record<string,unknown>;
 if(typeof input.id!=='string'||!uuidPattern.test(input.id)||typeof input.status!=='string'||!['contacted','market_review','proposal','closed','lost'].includes(input.status)||typeof input.expected_status!=='string'||!sellerStages.includes(input.expected_status as typeof sellerStages[number])||typeof input.reason!=='string'||input.reason.trim().length<5||input.reason.length>500)throw new Error('Check the stage and shared follow-up reason.');
 return {p_id:input.id,p_status:input.status,p_expected_status:input.expected_status,p_reason:input.reason.trim()};
}
export const sellerStageLabel=(status:string)=>({new:'Awaiting follow-up',contacted:'Contacted',market_review:'Property review',proposal:'Proposal',listed:'Listed',closed:'Closed',lost:'Not proceeding'}[status]||status);
export function sellerHandoff(value:unknown){
 if(!value||typeof value!=='object'||Array.isArray(value))throw new Error('Invalid proposal handoff.');const input=value as Record<string,unknown>;
 const text=(key:string,min:number,max:number)=>{const raw=input[key];if(typeof raw!=='string'||raw.trim().length<min||raw.length>max)throw new Error('Check approved public details and the shared approval reason.');return raw.trim();};
 const id=text('id',36,36),request=text('request_id',36,36),type=text('property_type',1,20);
 if(!uuidPattern.test(id)||!uuidPattern.test(request)||!['house','apartment','townhouse','land','commercial'].includes(type)||input.seller_approved!==true)throw new Error('Seller approval and valid draft details are required.');
 return {p_lead_id:id,p_request_id:request,p_public_title:text('public_title',3,160),p_public_area:text('public_area',2,120),p_property_type:type,p_approval_reason:text('approval_reason',5,500),p_seller_approved:true};
}
