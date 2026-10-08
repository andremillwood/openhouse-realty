import {uuidPattern} from '@/lib/enquiries/validation';
import {jamaicaTimestamp} from '@/lib/staff/jamaica-time';
export const serviceTargetKinds = ['response', 'resolution'] as const;
export type ServiceTargetKind = typeof serviceTargetKinds[number];
/** Explicit operational targets; no inferred SLA policy, completion or payment authority. */
export function serviceTargetInput(value: unknown) {
  if (!value || typeof value !== 'object' || Array.isArray(value)) throw Error('Check the service target.');
  const input = value as Record<string, unknown>;
  const keys = ['work_order_id','work_order_version','kind','version','action','due_at','reason','approved','request_id'];
  if (Object.keys(input).some(key => !keys.includes(key))) throw Error('Target identity and authority must come from verified records.');
  for (const key of ['work_order_id','request_id']) if (typeof input[key] !== 'string' || !uuidPattern.test(input[key])) throw Error('Valid work order and request references required.');
  for (const key of ['work_order_version','version']) if (typeof input[key] !== 'number' || !Number.isInteger(input[key]) || input[key] < (key === 'version' ? 0 : 1) || input[key] >= 2147483646) throw Error('Use the current work order and target revisions.');
  if (!serviceTargetKinds.includes(input.kind as typeof serviceTargetKinds[number]) || !['set','clear'].includes(input.action as string)) throw Error('Choose a response or resolution target action.');
  if (input.approved !== true || typeof input.reason !== 'string' || input.reason.trim().length < 5 || input.reason.length > 500) throw Error('Explicit approval and an explanation required.');
  let due: string | null = null;
  if (input.action === 'set') {
    if (typeof input.due_at !== 'string') throw Error('Enter a target date and time in Jamaica time.');
    due = jamaicaTimestamp(input.due_at);
    if (due < '2000-01-01T00:00:00.000Z' || due >= '2100-01-01T00:00:00.000Z') throw Error('Enter a supported target date.');
  } else if (input.due_at !== null) throw Error('Clearing a target must not include a deadline.');
  return Object.freeze({p_work_order_id:input.work_order_id as string,p_expected_work_order_version:input.work_order_version as number,p_kind:input.kind as typeof serviceTargetKinds[number],p_expected_version:input.version as number,p_action:input.action as 'set'|'clear',p_due_at:due,p_reason:input.reason.trim(),p_approved:true,p_request_id:input.request_id as string});
}
