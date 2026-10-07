export const financeAccountClasses = ['asset', 'liability', 'equity', 'income', 'expense'] as const;
export function financeAccountInput(value: unknown) {
  if (!value || typeof value !== 'object' || Array.isArray(value)) throw new Error('Invalid account request.');
  const input = value as Record<string, unknown>;
  if (typeof input.request_id !== 'string' || !/^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(input.request_id)) throw new Error('Provide a valid request reference.');
  if (typeof input.code !== 'string' || input.code.length > 80 || !/^[A-Z0-9][A-Z0-9._-]{0,39}$/.test(input.code.trim().toUpperCase())) throw new Error('Use an account code of up to forty letters, numbers, periods, underscores or hyphens.');
  if (typeof input.name !== 'string' || input.name.trim().length < 2 || input.name.length > 120 || typeof input.account_class !== 'string' || !financeAccountClasses.includes(input.account_class as typeof financeAccountClasses[number])) throw new Error('Provide the approved account name and classification.');
  if (typeof input.reason !== 'string' || input.reason.trim().length < 5 || input.reason.length > 500 || input.approved !== true) throw new Error('Provide the approval reason and confirm the account is approved.');
  return {p_request_id: input.request_id, p_code: input.code.trim().toUpperCase(), p_name: input.name.trim(), p_account_class: input.account_class, p_reason: input.reason.trim(), p_approved: true};
}
