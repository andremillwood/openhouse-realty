import {uuidPattern} from '@/lib/enquiries/validation';
export const applicationStatuses=['submitted','under_review','needs_info','approved','rejected','withdrawn','leased'] as const;
export const applicationLabel=(status:string)=>({submitted:'Submitted',under_review:'Under review',needs_info:'More information requested',approved:'Approved',rejected:'Not approved',withdrawn:'Withdrawn',leased:'Lease completed'}[status]||status);
export function applicationInput(value:unknown){
 if(!value||typeof value!=='object'||Array.isArray(value))throw new Error('Invalid application.');const input=value as Record<string,unknown>;
 const text=(key:string,min:number,max:number)=>{const raw=input[key];if(typeof raw!=='string'||raw.trim().length<min||raw.length>max)throw new Error(`Check ${key.replaceAll('_',' ')}.`);return raw.trim();};
 const request=text('request_id',36,36),listing=text('listing_id',36,36),enquiry=input.enquiry_id??null;
 if(!uuidPattern.test(request)||!uuidPattern.test(listing)||(enquiry!==null&&(typeof enquiry!=='string'||!uuidPattern.test(enquiry))))throw new Error('Invalid property or enquiry reference.');
 const size=input.household_size;if(typeof size!=='number'||!Number.isInteger(size)||size<1||size>20)throw new Error('Choose a household size between 1 and 20.');
 const move=text('desired_move_in',10,10);try{if(!/^\d{4}-\d{2}-\d{2}$/.test(move)||new Date(`${move}T00:00:00Z`).toISOString().slice(0,10)!==move)throw new Error();}catch{throw new Error('Choose a valid move-in date.');}
 if(input.consent!==true)throw new Error('Consent is required for application review.');
 return {p_request_id:request,p_listing_id:listing,p_enquiry_id:enquiry as string|null,p_contact_name:text('contact_name',2,120),p_phone:text('phone',0,40),p_household_size:size,p_desired_move_in:move,p_message:text('message',10,2000),p_consent:true};
}
export function applicationTransition(value:unknown){
 if(!value||typeof value!=='object'||Array.isArray(value))throw new Error('Invalid application update.');const input=value as Record<string,unknown>;
 if(typeof input.id!=='string'||!uuidPattern.test(input.id)||typeof input.request_id!=='string'||!uuidPattern.test(input.request_id)||typeof input.version!=='number'||!Number.isInteger(input.version)||input.version<1||input.version>=2147483647||typeof input.action!=='string'||!['start_review','request_info','reject','reply','withdraw'].includes(input.action)||typeof input.message!=='string'||input.message.trim().length<5||input.message.length>2000)throw new Error('Check the action and shared reply or decision reason.');
 return {p_id:input.id,p_request_id:input.request_id,p_expected_version:input.version,p_action:input.action,p_message:input.message.trim()};
}
export function jamaicaToday(now=new Date()){
 const parts=new Intl.DateTimeFormat('en-JM',{timeZone:'America/Jamaica',year:'numeric',month:'2-digit',day:'2-digit'}).formatToParts(now);const part=(type:string)=>parts.find(row=>row.type===type)?.value;
 return `${part('year')}-${part('month')}-${part('day')}`;
}
