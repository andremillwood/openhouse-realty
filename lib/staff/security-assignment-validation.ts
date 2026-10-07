export function securityAssignmentInput(value: unknown) {
  if (!value || typeof value !== 'object' || Array.isArray(value)) throw new Error('Invalid security assignment request.');
  const input = value as Record<string, unknown>, uuid = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
  if (typeof input.request_id !== 'string' || !uuid.test(input.request_id) || !(input.assignment_id === null || typeof input.assignment_id === 'string' && uuid.test(input.assignment_id))) throw new Error('Check the assignment reference.');
  if (typeof input.version !== 'number' || !Number.isInteger(input.version) || input.version < 0 || input.version >= 2147483647) throw new Error('Refresh the assignment revision.');
  if (typeof input.is_active !== 'boolean' || input.approved !== true || typeof input.reason !== 'string' || input.reason.trim().length < 5 || input.reason.length > 500) throw new Error('Record approval and a decision reason.');
  let email: string|null = null, property: string|null = null;
  if (input.assignment_id === null) {
    if (input.version !== 0 || !input.is_active || typeof input.property_id !== 'string' || !uuid.test(input.property_id) || typeof input.email !== 'string' || input.email.length > 254 || !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(input.email.trim())) throw new Error('New assignments need a property and approved verified email.');
    property = input.property_id; email = input.email.trim().toLowerCase();
  } else {
    if (input.version < 1) throw new Error('Current assignment revision required.');
    if (input.property_id !== undefined && input.property_id !== null || input.email !== undefined && input.email !== null) throw new Error('Existing property and security account cannot change.');
  }
  return {p_request_id: input.request_id, p_assignment_id: input.assignment_id as string|null, p_expected_version: input.version, p_property_id: property, p_email: email, p_is_active: input.is_active, p_reason: input.reason.trim(), p_approved: true};
}
