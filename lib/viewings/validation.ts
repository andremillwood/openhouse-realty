import { uuidPattern } from '@/lib/enquiries/validation';
export function viewingRequestInput(value:unknown){
 if(!value||typeof value!=='object'||Array.isArray(value))throw new Error('Invalid viewing request.');
 const input=value as Record<string,unknown>;
 for(const key of ['request_id','slot_id'])if(typeof input[key]!=='string'||!uuidPattern.test(input[key]))throw new Error('Invalid viewing reference.');
 if(input.enquiry_id!=null&&(typeof input.enquiry_id!=='string'||!uuidPattern.test(input.enquiry_id)))throw new Error('Invalid enquiry reference.');
 if(typeof input.contact_name!=='string'||input.contact_name.trim().length<2||input.contact_name.length>120)throw new Error('Enter your name.');
 if(typeof input.phone!=='string'||input.phone.length>40)throw new Error('Check your phone number.');
 if(input.consent!==true)throw new Error('Consent is required for this request.');
 return {p_request_id:input.request_id as string,p_slot_id:input.slot_id as string,p_enquiry_id:(input.enquiry_id??null) as string|null,p_contact_name:input.contact_name.trim(),p_phone:input.phone.trim(),p_consent:true};
}
export function viewingTransitionInput(value:unknown){
 if(!value||typeof value!=='object'||Array.isArray(value))throw new Error('Invalid viewing action.');
 const input=value as Record<string,unknown>;
 if(typeof input.viewing_id!=='string'||!uuidPattern.test(input.viewing_id)||typeof input.action!=='string'||!['confirm','cancel','complete','no_show'].includes(input.action))throw new Error('Invalid viewing action.');
 if(typeof input.reason!=='string'||input.reason.length>500||(input.action==='cancel'&&input.reason.trim().length<5))throw new Error('Provide a cancellation reason of 5 to 500 characters.');
 return {p_viewing_id:input.viewing_id,p_action:input.action,p_reason:input.reason.trim()};
}
export function slotInput(value:unknown){
 if(!value||typeof value!=='object'||Array.isArray(value))throw new Error('Invalid availability.');
 const input=value as Record<string,unknown>;
 if(input.action==='close'){
  if(typeof input.slot_id!=='string'||!uuidPattern.test(input.slot_id))throw new Error('Invalid slot reference.');
  return {p_action:'close',p_slot_id:input.slot_id,p_request_id:null,p_listing_id:null,p_starts_at:null,p_ends_at:null};
 }
 if(input.action!=='create'||typeof input.request_id!=='string'||!uuidPattern.test(input.request_id)||typeof input.listing_id!=='string'||!uuidPattern.test(input.listing_id))throw new Error('Choose a property and valid availability reference.');
 const time=(key:string)=>{const raw=input[key];if(typeof raw!=='string'||!/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}(:\d{2}(\.\d{1,3})?)?(Z|[+-]\d{2}:\d{2})$/.test(raw))throw new Error('Use a time with an explicit timezone.');const calendar=new Date(`${raw.slice(0,10)}T00:00:00.000Z`);if(!Number.isFinite(calendar.getTime())||calendar.toISOString().slice(0,10)!==raw.slice(0,10))throw new Error('Invalid calendar date.');const date=new Date(raw);if(!Number.isFinite(date.getTime()))throw new Error('Invalid availability time.');return date;};
 const start=time('starts_at'),end=time('ends_at');const duration=end.getTime()-start.getTime();
 if(duration<15*60000||duration>120*60000)throw new Error('Viewing slots must last 15 to 120 minutes.');
 return {p_action:'create',p_request_id:input.request_id,p_slot_id:null,p_listing_id:input.listing_id,p_starts_at:start.toISOString(),p_ends_at:end.toISOString()};
}
export function jamaicaInputToIso(value:string){
 if(!/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}$/.test(value))throw new Error('Choose a valid date and time.');
 const calendar=new Date(`${value.slice(0,10)}T00:00:00.000Z`);if(!Number.isFinite(calendar.getTime())||calendar.toISOString().slice(0,10)!==value.slice(0,10))throw new Error('Choose a valid calendar date.');
 const date=new Date(`${value}:00-05:00`);
 if(!Number.isFinite(date.getTime()))throw new Error('Choose a valid date and time.');
 return date.toISOString();
}
export function viewingTime(value:string){return new Intl.DateTimeFormat('en-JM',{timeZone:'America/Jamaica',dateStyle:'medium',timeStyle:'short'}).format(new Date(value));}
