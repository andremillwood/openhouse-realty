export function presenceInput(value: unknown) {
  if (!value || typeof value !== 'object' || Array.isArray(value)) throw new Error('Invalid presence request.');
  const input = value as Record<string, unknown>;
  const uuid = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
  const reference = (value: unknown): value is string => typeof value === 'string' && uuid.test(value);
  if (!reference(input.request_id)) throw new Error('Check the request reference.');
  if (!['check_in', 'check_out'].includes(String(input.action))) throw new Error('Choose arrival or departure.');
  if (typeof input.reason !== 'string' || input.reason.trim().length < 5 || input.reason.length > 500) throw new Error('Record a reason of 5 to 500 characters.');
  if (typeof input.version !== 'number' || !Number.isInteger(input.version) || input.version < 0 || input.version >= 2147483647) throw new Error('Refresh the presence revision.');
  let permit: string | null = null, presence: string | null = null, identity: boolean | null = null;
  if (input.action === 'check_in') {
    if (!reference(input.permit_id) || input.presence_id != null || input.version !== 0 || input.identity_checked !== true) throw new Error('Arrival requires a current permit and an identity check.');
    permit = input.permit_id; identity = true;
  } else {
    if (!reference(input.presence_id) || input.permit_id != null || input.identity_checked != null || input.version < 1) throw new Error('Departure requires the current presence revision.');
    presence = input.presence_id;
  }
  return {p_request_id: input.request_id, p_action: input.action, p_permit_id: permit, p_presence_id: presence, p_expected_version: input.version, p_identity_checked: identity, p_reason: input.reason.trim()};
}
