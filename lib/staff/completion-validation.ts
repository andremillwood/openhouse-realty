export function completionInput(value: unknown) {
  if (!value || typeof value !== 'object' || Array.isArray(value)) throw new Error('Invalid completion request.');
  const input = value as Record<string, unknown>;
  const reference = (value: unknown): value is string => typeof value === 'string' && /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(value);
  const revision = (value: unknown): value is number => typeof value === 'number' && Number.isInteger(value) && value >= 1 && value < 2147483647;
  const text = (value: unknown, min: number, max: number): value is string => typeof value === 'string' && value.trim().length >= min && value.length <= max;
  if (!reference(input.request_id) || !text(input.reason, 5, 500)) throw new Error('Provide a request reference and decision reason.');
  if (!['submit', 'request_changes', 'approve'].includes(String(input.action))) throw new Error('Choose a valid completion action.');
  if (input.action === 'submit') {
    if (!reference(input.offer_id) || !revision(input.offer_version) || input.report_id != null || input.version !== 0) throw new Error('Refresh the current assignment before submitting.');
    if (!text(input.summary, 20, 4000) || !text(input.tests_performed, 10, 2000) || !text(input.outstanding_items, 5, 2000)) throw new Error('Describe the work, tests performed and outstanding items.');
    if (input.review_message != null || input.evidence_reviewed != null) throw new Error('Contractor submissions cannot include a manager review.');
    return {p_request_id: input.request_id, p_action: 'submit', p_offer_id: input.offer_id, p_report_id: null, p_expected_offer_version: input.offer_version, p_expected_report_version: 0, p_summary: input.summary.trim(), p_tests_performed: input.tests_performed.trim(), p_outstanding_items: input.outstanding_items.trim(), p_review_message: null, p_reason: input.reason.trim(), p_evidence_reviewed: null};
  }
  if (!reference(input.report_id) || !revision(input.version) || !text(input.review_message, 10, 2000)) throw new Error('Provide the current report revision and a review message shared with the contractor.');
  for (const key of ['offer_id', 'offer_version', 'summary', 'tests_performed', 'outstanding_items']) if (input[key] != null) throw new Error('Reviews cannot rewrite the submitted evidence.');
  if (input.action === 'approve' ? input.evidence_reviewed !== true : input.evidence_reviewed != null) throw new Error('Approval requires a fresh evidence review confirmation.');
  return {p_request_id: input.request_id, p_action: input.action as string, p_offer_id: null, p_report_id: input.report_id, p_expected_offer_version: null, p_expected_report_version: input.version, p_summary: null, p_tests_performed: null, p_outstanding_items: null, p_review_message: input.review_message.trim(), p_reason: input.reason.trim(), p_evidence_reviewed: input.action === 'approve' ? true : null};
}
