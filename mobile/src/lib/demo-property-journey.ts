export type DemoJourneyRole='prospect'|'realtor'|'manager';
export type DemoJourneyAction='request_viewing'|'confirm_viewing'|'prepare_checklist'|'submit_application'|'approve_application';
export type DemoPropertyJourney=Readonly<{property:string;viewing:'none'|'requested'|'confirmed';checklist:boolean;application:'none'|'submitted'|'approved';history:readonly {action:DemoJourneyAction;role:DemoJourneyRole}[]}>;
export function initialPropertyJourney(property:string):DemoPropertyJourney{if(!/^[a-z0-9-]{1,80}$/.test(property))throw Error('Demo property required.');return {property,viewing:'none',checklist:false,application:'none',history:[]};}
export function propertyJourneyActions(state:DemoPropertyJourney,role:DemoJourneyRole):DemoJourneyAction[]{
 if(role==='prospect'){const actions:DemoJourneyAction[]=[];if(state.viewing==='none')actions.push('request_viewing');if(!state.checklist)actions.push('prepare_checklist');if(state.viewing==='confirmed'&&state.checklist&&state.application==='none')actions.push('submit_application');return actions;}
 if(role==='realtor')return state.viewing==='requested'?['confirm_viewing']:[];
 if(role==='manager')return state.application==='submitted'?['approve_application']:[];
 return [];
}
export function advancePropertyJourney(state:DemoPropertyJourney,property:string,role:DemoJourneyRole,action:DemoJourneyAction):DemoPropertyJourney{
 if(state.property!==property||!propertyJourneyActions(state,role).includes(action))return state;
 const patch=action==='request_viewing'?{viewing:'requested' as const}:action==='confirm_viewing'?{viewing:'confirmed' as const}:action==='prepare_checklist'?{checklist:true}:action==='submit_application'?{application:'submitted' as const}:{application:'approved' as const};
 return {...state,...patch,history:[...state.history,{action,role}]};
}
