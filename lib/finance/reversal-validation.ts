export function reversalInput(value: unknown) {
  if (!value || typeof value !== 'object' || Array.isArray(value)) throw new Error('Invalid reversal request.');
  const input = value as Record<string, unknown>;
  const uuid = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
  if (typeof input.request_id !== 'string' || !uuid.test(input.request_id) || typeof input.journal_id !== 'string' || !uuid.test(input.journal_id)) throw new Error('Valid journal and request references required.');
  if (typeof input.reason !== 'string' || input.reason.trim().length < 5 || input.reason.length > 500 || input.approved !== true) throw new Error('Provide a reversal reason and explicit approval.');
  return {p_request_id: input.request_id, p_journal_id: input.journal_id, p_reason: input.reason.trim(), p_approved: true};
}
