export function returnVisitInput(value: unknown) {
  if (!value || typeof value !== 'object' || Array.isArray(value)) throw new Error('Invalid return-visit request.');
  const input = value as Record<string, unknown>;
  const reference = (value: unknown): value is string => typeof value === 'string' && /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(value);
  const revision = (value: unknown): value is number => typeof value === 'number' && Number.isInteger(value) && value >= 1 && value < 2147483647;
  if (!reference(input.request_id) || !reference(input.report_id)) throw new Error('Provide valid request and report references.');
  if (!revision(input.report_version) || !revision(input.offer_version) || !revision(input.work_version)) throw new Error('Refresh the report and assignment before requesting a return visit.');
  if (typeof input.reason !== 'string' || input.reason.trim().length < 5 || input.reason.length > 500 || input.approved !== true) throw new Error('Provide a decision reason and confirm return-visit approval.');
  return {p_request_id: input.request_id, p_report_id: input.report_id, p_expected_report_version: input.report_version, p_expected_offer_version: input.offer_version, p_expected_work_version: input.work_version, p_reason: input.reason.trim(), p_approved: true};
}
