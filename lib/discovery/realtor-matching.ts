export type RealtorProfile = { id:string;display_name:string;bio:string;photo_url:string|null;service_areas:string[];supported_intents:string[];communication_style:string;guidance_style:string;decision_pace:string };
export type WorkingPreferences = { intent:string;preferred_area:string;communication_style:string;guidance_style:string;decision_pace:string };
export function rankRealtors(roster: RealtorProfile[], preferences: WorkingPreferences) {
  const labels = { communication_style:'communication style', guidance_style:'guidance preference', decision_pace:'decision pace' };
  return roster.filter(realtor=>realtor.service_areas.includes(preferences.preferred_area)&&realtor.supported_intents.includes(preferences.intent)).map(realtor=>{
    const reasons=[`Serves ${preferences.preferred_area}`,`Supports your ${preferences.intent} journey`];
    let points=2;
    for(const key of ['communication_style','guidance_style','decision_pace'] as const) if(realtor[key]===preferences[key]) { points+=2;reasons.push(`Matches your ${labels[key]}`); }
    return {realtor,points,reasons};
  }).sort((a,b)=>b.points-a.points||a.realtor.display_name.localeCompare(b.realtor.display_name)||a.realtor.id.localeCompare(b.realtor.id));
}
