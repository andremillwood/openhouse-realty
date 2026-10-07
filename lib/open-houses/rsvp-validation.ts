const uuid=/^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
export function rsvpInput(value:unknown){
 if(!value||typeof value!=='object'||Array.isArray(value))throw new Error('Reservation details required.');const body=value as Record<string,unknown>;
 if(typeof body.event_id!=='string'||!uuid.test(body.event_id)||typeof body.request_id!=='string'||!uuid.test(body.request_id)||!Number.isInteger(body.version)||Number(body.version)<0||Number(body.version)>=2147483647||!['reserve','cancel'].includes(String(body.action)))throw new Error('Check the reservation reference and refresh before retrying.');
 if(body.action==='reserve'&&(!Number.isInteger(body.party_size)||Number(body.party_size)<1||Number(body.party_size)>6||body.consent!==true))throw new Error('Choose one to six attendees and agree to attendance contact.');
 return {p_event_id:body.event_id,p_request_id:body.request_id,p_expected_version:Number(body.version),p_party_size:body.action==='reserve'?Number(body.party_size):null,p_action:String(body.action),p_consent:body.action==='reserve'?true:null};
}
