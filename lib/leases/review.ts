import {uuidPattern} from '@/lib/enquiries/validation';
import {applicantLeaseSummaryResult} from '@/lib/leases/summary';
export type LeaseReviewAction='reviewed'|'question'|'answer';
export function leaseReviewInput(value:unknown){
 if(!value||typeof value!=='object'||Array.isArray(value))throw new Error('Check the summary response.');const input=value as Record<string,unknown>;
 for(const key of ['release_id','request_id'])if(typeof input[key]!=='string'||!uuidPattern.test(input[key] as string))throw new Error('Valid release and request references required.');
 if(typeof input.version!=='number'||!Number.isInteger(input.version)||input.version<0||input.version>=2147483646||!['reviewed','question','answer'].includes(input.action as string)||input.review_only_acknowledged!==true||typeof input.message!=='string')throw new Error('Use the current review version and acknowledge this review-only response.');
 const message=input.message.trim();if(input.action==='reviewed'?message!=='':message.length<10||message.length>2000)throw new Error('Questions and replies need 10–2000 characters; a recorded review has no message.');
 return {p_release_id:input.release_id as string,p_request_id:input.request_id as string,p_expected_version:input.version,p_action:input.action as LeaseReviewAction,p_message:message,p_review_only_acknowledged:true};
}
export type LeaseReviewEvent={id:string;version:number;action:LeaseReviewAction;actor_kind:'applicant'|'staff';message:string;created_at:string};
export function leaseReviewHistory(value:unknown){
 if(!value||typeof value!=='object'||Array.isArray(value))throw new Error('Review history unavailable.');const data=value as Record<string,unknown>;
 if(typeof data.release_id!=='string'||!uuidPattern.test(data.release_id)||!['applicant','staff'].includes(data.role as string)||typeof data.current!=='boolean'||typeof data.revision!=='number'||!Number.isInteger(data.revision)||data.revision<0||data.revision>=2147483647||data.total!==data.revision||!Array.isArray(data.items)||data.items.length>25||data.items.length>data.revision||(data.revision===0?data.latest_action!==null:!['reviewed','question','answer'].includes(data.latest_action as string)))throw new Error('Review history unavailable.');
 const summary=applicantLeaseSummaryResult({total:1,items:[data.summary]}).items[0];const seen=new Set<string>();let previous=data.revision+1;
 for(const raw of data.items){if(!raw||typeof raw!=='object'||Array.isArray(raw))throw new Error('Review history unavailable.');const item=raw as Record<string,unknown>;
  if(typeof item.id!=='string'||!uuidPattern.test(item.id)||seen.has(item.id)||typeof item.version!=='number'||!Number.isInteger(item.version)||item.version<1||item.version>=previous||!['reviewed','question','answer'].includes(item.action as string)||item.actor_kind!==(item.action==='answer'?'staff':'applicant')||typeof item.message!=='string'||(item.action==='reviewed'?item.message!=='':item.message.length<10||item.message.length>2000)||typeof item.created_at!=='string'||!Number.isFinite(Date.parse(item.created_at)))throw new Error('Review history unavailable.');seen.add(item.id);previous=item.version;
 }
 return {release_id:data.release_id,role:data.role as 'applicant'|'staff',current:data.current,revision:data.revision,total:data.revision,latest_action:data.latest_action as LeaseReviewAction|null,summary,items:data.items as LeaseReviewEvent[]};
}
