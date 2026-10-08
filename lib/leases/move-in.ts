import {uuidPattern} from '@/lib/enquiries/validation';
export const moveInPreparationKinds=['unit_readiness','utilities','access_preparation'] as const;
export const moveInPreparationStates=['pending','ready','blocked'] as const;
export type MoveInPreparationKind=typeof moveInPreparationKinds[number];
export type MoveInPreparationState=typeof moveInPreparationStates[number];
/** Operational evidence only; signed lease, payment, tenancy and household authority are independently verified. */
export function moveInPreparationInput(value:unknown){
 if(!value||typeof value!=='object'||Array.isArray(value))throw new Error('Check the move-in preparation record.');
 const input=value as Record<string,unknown>;
 const keys=['draft_id','draft_version','kind','version','state','evidence_reference','reason','request_id','approved'];
 if(Object.keys(input).some(key=>!keys.includes(key)))throw new Error('Tenancy, payment and participant authority must come from verified records.');
 for(const key of ['draft_id','request_id'])if(typeof input[key]!=='string'||!uuidPattern.test(input[key] as string))throw new Error('Valid draft and request references required.');
 for(const key of ['draft_version','version']){const v=input[key];if(typeof v!=='number'||!Number.isInteger(v)||v<(key==='version'?0:1)||v>=2147483646)throw new Error('Use the current draft and preparation versions.');}
 if(!moveInPreparationKinds.includes(input.kind as MoveInPreparationKind)||!moveInPreparationStates.includes(input.state as MoveInPreparationState)||input.approved!==true)throw new Error('Choose a preparation item, status and explicit approval.');
 const text=(key:string,min:number)=>{const v=input[key];if(typeof v!=='string'||v.length>500||v.trim().length<min)throw new Error('Record an explanation and evidence for ready items.');return v.trim();};
 const reason=text('reason',5),evidence=text('evidence_reference',input.state==='ready'?5:0);
 return Object.freeze({p_draft_id:input.draft_id as string,p_expected_draft_version:input.draft_version as number,p_kind:input.kind as MoveInPreparationKind,p_expected_version:input.version as number,p_state:input.state as MoveInPreparationState,p_evidence_reference:evidence,p_reason:reason,p_request_id:input.request_id as string,p_approved:true});
}
