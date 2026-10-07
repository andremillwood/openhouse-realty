export function workOfferInput(value: unknown) {
  if (!value || typeof value !== 'object' || Array.isArray(value)) throw new Error('Invalid work offer request.');
  const input = value as Record<string, unknown>;
  const uuid = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
  const reference = (value: unknown): value is string => typeof value === 'string' && uuid.test(value);
  const revision = (value: unknown): value is number => typeof value === 'number' && Number.isInteger(value) && value >= 1 && value < 2147483647;
  const text = (value: unknown, min: number, max: number): value is string => typeof value === 'string' && value.trim().length >= min && value.length <= max;
  if (!reference(input.request_id) || !text(input.reason, 5, 500)) throw new Error('Provide a request reference and reason.');
  if (!['offer', 'withdraw', 'accept', 'decline', 'release'].includes(String(input.action))) throw new Error('Choose a valid offer action.');
  if (input.action === 'offer') {
    if (input.offer_id !== null || input.version !== 0 || !reference(input.work_order_id) || !reference(input.contractor_id) || !revision(input.work_version)) throw new Error('Refresh the work order and selected contractor.');
    if (!text(input.job_title, 3, 160) || !text(input.scope_summary, 20, 3000) || !text(input.trade, 1, 80) || input.approved !== true) throw new Error('Approve the title, scope and contractor trade before sharing.');
    return {p_request_id: input.request_id, p_action: 'offer', p_offer_id: null, p_work_order_id: input.work_order_id, p_contractor_id: input.contractor_id, p_expected_offer_version: 0, p_expected_work_version: input.work_version, p_job_title: input.job_title.trim(), p_scope_summary: input.scope_summary.trim(), p_trade: input.trade.trim(), p_reason: input.reason.trim(), p_approved: true};
  }
  if (!reference(input.offer_id) || !revision(input.version)) throw new Error('Refresh the offer before responding.');
  for (const key of ['work_order_id', 'contractor_id', 'work_version', 'job_title', 'scope_summary', 'trade', 'approved']) {
    if (input[key] !== undefined && input[key] !== null) throw new Error('Offer responses cannot change the approved scope.');
  }
  return {p_request_id: input.request_id, p_action: input.action as string, p_offer_id: input.offer_id, p_work_order_id: null, p_contractor_id: null, p_expected_offer_version: input.version, p_expected_work_version: null, p_job_title: null, p_scope_summary: null, p_trade: null, p_reason: input.reason.trim(), p_approved: null};
}
