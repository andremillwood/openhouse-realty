export function entryPermitInput(value: unknown) {
  if (!value || typeof value !== 'object' || Array.isArray(value)) throw new Error('Invalid entry permit request.');
  const input = value as Record<string, unknown>;
  const uuid = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
  const reference = (value: unknown): value is string => typeof value === 'string' && uuid.test(value);
  const revision = (value: unknown): value is number => typeof value === 'number' && Number.isInteger(value) && value >= 1 && value < 2147483647;
  const timestamp = (value: unknown): value is string => typeof value === 'string' && /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{3}Z$/.test(value) && Number.isFinite(Date.parse(value)) && new Date(value).toISOString() === value;
  if (!reference(input.request_id) || typeof input.reason !== 'string' || input.reason.trim().length < 10 || input.reason.length > 500) throw new Error('Provide a request reference and authority reason.');
  if (!['authorize','revoke'].includes(String(input.action))) throw new Error('Choose a valid entry decision.');
  if (input.action === 'authorize') {
    if (input.permit_id !== null || input.version !== 0 || !reference(input.visit_id) || !revision(input.visit_version)) throw new Error('Refresh the confirmed appointment before authorizing entry.');
    if (!timestamp(input.valid_from) || !timestamp(input.valid_until) || Date.parse(input.valid_until) <= Date.parse(input.valid_from) || Date.parse(input.valid_until)-Date.parse(input.valid_from) > 8*60*60*1000) throw new Error('Provide a valid access window of up to eight hours.');
    if (typeof input.shared_instructions !== 'string' || input.shared_instructions.trim().length < 5 || input.shared_instructions.length > 1000 || input.approved !== true) throw new Error('Approve the entry instructions and record your access authority.');
    return {p_request_id: input.request_id, p_action: 'authorize', p_permit_id: null, p_visit_id: input.visit_id, p_expected_version: 0, p_expected_visit_version: input.visit_version, p_valid_from: input.valid_from, p_valid_until: input.valid_until, p_shared_instructions: input.shared_instructions.trim(), p_reason: input.reason.trim(), p_approved: true};
  }
  if (!reference(input.permit_id) || !revision(input.version)) throw new Error('Refresh the permit before revoking entry.');
  for (const key of ['visit_id','visit_version','valid_from','valid_until','shared_instructions','approved']) if (input[key] !== undefined && input[key] !== null) throw new Error('Revocation cannot change the approved access window.');
  return {p_request_id: input.request_id, p_action: input.action as string, p_permit_id: input.permit_id, p_visit_id: null, p_expected_version: input.version, p_expected_visit_version: null, p_valid_from: null, p_valid_until: null, p_shared_instructions: null, p_reason: input.reason.trim(), p_approved: null};
}
