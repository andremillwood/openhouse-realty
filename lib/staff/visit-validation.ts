export function visitInput(value: unknown) {
  if (!value || typeof value !== 'object' || Array.isArray(value)) throw new Error('Invalid visit request.');
  const input = value as Record<string, unknown>;
  const uuid = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
  const reference = (value: unknown): value is string => typeof value === 'string' && uuid.test(value);
  const revision = (value: unknown): value is number => typeof value === 'number' && Number.isInteger(value) && value >= 1 && value < 2147483647;
  const timestamp = (value: unknown): value is string => typeof value === 'string' && /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{3}Z$/.test(value) && Number.isFinite(Date.parse(value)) && new Date(value).toISOString() === value;
  if (!reference(input.request_id) || typeof input.reason !== 'string' || input.reason.trim().length < 5 || input.reason.length > 500) throw new Error('Provide a request reference and decision reason.');
  if (!['propose','confirm','decline','cancel'].includes(String(input.action))) throw new Error('Choose a valid visit action.');
  if (input.action === 'propose') {
    if (input.visit_id !== null || input.version !== 0 || !reference(input.offer_id) || !revision(input.offer_version)) throw new Error('Refresh the accepted assignment before proposing a visit.');
    if (!timestamp(input.starts_at) || !timestamp(input.ends_at) || Date.parse(input.ends_at) <= Date.parse(input.starts_at) || Date.parse(input.ends_at)-Date.parse(input.starts_at) > 8*60*60*1000) throw new Error('Provide a valid visit window of up to eight hours.');
    if (typeof input.shared_note !== 'string' || input.shared_note.trim().length < 5 || input.shared_note.length > 1000 || input.approved !== true) throw new Error('Approve the visit note before sharing.');
    return {p_request_id: input.request_id, p_action: 'propose', p_visit_id: null, p_offer_id: input.offer_id, p_expected_version: 0, p_expected_offer_version: input.offer_version, p_starts_at: input.starts_at, p_ends_at: input.ends_at, p_shared_note: input.shared_note.trim(), p_reason: input.reason.trim(), p_approved: true};
  }
  if (!reference(input.visit_id) || !revision(input.version)) throw new Error('Refresh the visit before responding.');
  for (const key of ['offer_id','offer_version','starts_at','ends_at','shared_note','approved']) if (input[key] !== undefined && input[key] !== null) throw new Error('Responses cannot change the approved visit window.');
  return {p_request_id: input.request_id, p_action: input.action as string, p_visit_id: input.visit_id, p_offer_id: null, p_expected_version: input.version, p_expected_offer_version: null, p_starts_at: null, p_ends_at: null, p_shared_note: null, p_reason: input.reason.trim(), p_approved: null};
}
