import {uuidPattern} from '@/lib/enquiries/validation';
export function openHouseInput(value:unknown,now=new Date()){
 if(!value||typeof value!=='object'||Array.isArray(value))throw new Error('Invalid event.');const input=value as Record<string,unknown>;
 if(typeof input.request_id!=='string'||!uuidPattern.test(input.request_id)||typeof input.version!=='number'||!Number.isInteger(input.version)||input.version<0||input.version>=2147483647)throw new Error('Valid request and current version required.');
 const base={p_action:input.action,p_request_id:input.request_id,p_expected_version:input.version};
 if(input.action==='create'){
  if(input.version!==0||typeof input.listing_id!=='string'||!uuidPattern.test(input.listing_id)||typeof input.title!=='string'||input.title.trim().length<3||input.title.length>160||typeof input.capacity!=='number'||!Number.isInteger(input.capacity)||input.capacity<1||input.capacity>250||input.approved!==true)throw new Error('Choose a published listing, approved title and visitor capacity.');
  const date=(raw:unknown)=>{if(typeof raw!=='string'||!/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d{3})?Z$/.test(raw)||!Number.isFinite(Date.parse(raw))||new Date(raw).toISOString().slice(0,19)!==raw.slice(0,19))throw new Error('Use real UTC event times.');return new Date(raw);};const start=date(input.starts_at),end=date(input.ends_at),duration=end.getTime()-start.getTime();if(start.getTime()<now.getTime()+1800000||start.getTime()>now.getTime()+120*86400000||duration<900000||duration>8*3600000)throw new Error('Schedule 30 minutes to 120 days ahead, for 15 minutes to 8 hours.');
  return {...base,p_event_id:null,p_listing_id:input.listing_id,p_title:input.title.trim(),p_starts_at:start.toISOString(),p_ends_at:end.toISOString(),p_capacity:input.capacity,p_reason:null,p_approved:true};
 }
 if(!['cancel','complete'].includes(input.action as string)||input.version<1||typeof input.event_id!=='string'||!uuidPattern.test(input.event_id)||typeof input.reason!=='string'||input.reason.trim().length<5||input.reason.length>500)throw new Error('Choose a valid event action and reason.');
 return {...base,p_event_id:input.event_id,p_listing_id:null,p_title:null,p_starts_at:null,p_ends_at:null,p_capacity:null,p_reason:input.reason.trim(),p_approved:null};
}
