const uuid = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
export function ownerAccessInput(value: unknown) {
  if (!value || typeof value !== 'object' || Array.isArray(value)) throw new Error('Invalid owner access request.');
  const input = value as Record<string, unknown>;
  if (typeof input.request_id !== 'string' || !uuid.test(input.request_id) || !(input.access_id === null || typeof input.access_id === 'string' && uuid.test(input.access_id))) throw new Error('Check the access reference.');
  if (typeof input.version !== 'number' || !Number.isInteger(input.version) || input.version < 0 || input.version >= 2147483647) throw new Error('Refresh the access revision.');
  if (typeof input.is_active !== 'boolean' || input.approved !== true || typeof input.reason !== 'string' || input.reason.trim().length < 5 || input.reason.length > 500) throw new Error('Record access approval and a change reason.');
  let property: string | null = null;
  let email: string | null = null;
  if (input.access_id === null) {
    if (input.version !== 0 || !input.is_active || typeof input.property_id !== 'string' || !uuid.test(input.property_id) || typeof input.email !== 'string' || input.email.length > 254 || !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(input.email.trim())) throw new Error('New access needs an approved property and verified account email.');
    property = input.property_id;
    email = input.email.trim().toLowerCase();
  } else if (input.version < 1 || input.property_id != null || input.email != null) {
    throw new Error('Existing access identity cannot be changed; use the current revision.');
  }
  return { p_request_id: input.request_id, p_access_id: input.access_id as string | null, p_expected_version: input.version, p_property_id: property, p_email: email, p_is_active: input.is_active, p_reason: input.reason.trim(), p_approved: true };
}
