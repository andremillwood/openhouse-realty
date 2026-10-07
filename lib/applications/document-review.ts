import {uuidPattern} from '@/lib/enquiries/validation';
export const documentReviewStatuses=['verified','needs_info','not_accepted'] as const;
export const documentReviewLabel=(status:string)=>({verified:'Verified by staff',needs_info:'Clarification needed',not_accepted:'Not accepted'}[status]||'Not reviewed');
export function documentReviewInput(value:unknown){
 if(!value||typeof value!=='object'||Array.isArray(value))throw new Error('Invalid document review.');const input=value as Record<string,unknown>;
 if(typeof input.document_id!=='string'||!uuidPattern.test(input.document_id)||typeof input.request_id!=='string'||!uuidPattern.test(input.request_id)||typeof input.version!=='number'||!Number.isInteger(input.version)||input.version<0||input.version>=2147483647||typeof input.status!=='string'||!documentReviewStatuses.includes(input.status as typeof documentReviewStatuses[number])||typeof input.reason!=='string'||input.reason.trim().length<5||input.reason.length>2000)throw new Error('Choose a document decision and record a reason between 5 and 2,000 characters.');
 return {p_document_id:input.document_id,p_request_id:input.request_id,p_expected_version:input.version,p_status:input.status,p_reason:input.reason.trim()};
}
