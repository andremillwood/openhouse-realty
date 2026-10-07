export const uuidPattern = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
export function enquiryInput(value:unknown) {
  if(!value||typeof value!=='object'||Array.isArray(value))throw new Error('Invalid enquiry.');
  const input=value as Record<string,unknown>;
  const text=(key:string,min:number,max:number)=>{const v=input[key];if(typeof v!=='string'||v.trim().length<min||v.length>max)throw new Error(`Check ${key.replaceAll('_',' ')}.`);return v.trim();};
  const requestId=text('request_id',36,36);if(!uuidPattern.test(requestId))throw new Error('Invalid request reference.');
  const listingId=input.listing_id??null;const realtorId=input.realtor_id??null;
  if((listingId===null)===(realtorId===null)||[listingId,realtorId].some(id=>id!==null&&(typeof id!=='string'||!uuidPattern.test(id))))throw new Error('Choose one published property or realtor.');
  if(input.consent!==true)throw new Error('Consent is required to contact the team.');
  return {p_request_id:requestId,p_listing_id:listingId as string|null,p_realtor_id:realtorId as string|null,p_contact_name:text('contact_name',2,120),p_phone:text('phone',0,40),p_message:text('message',10,4000),p_consent:true};
}
