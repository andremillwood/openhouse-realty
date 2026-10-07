const uuid = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const maximumLineMinor = 99999999999999;
export type JournalLine = {account_id: string; debit_minor: number; credit_minor: number; property_id: string | null; unit_id: string | null};
/** Amounts are whole Jamaican-dollar cents; no floating-point conversion is performed. */
export function journalInput(value: unknown) {
  if (!value || typeof value !== 'object' || Array.isArray(value)) throw new Error('Invalid journal request.');
  const input = value as Record<string, unknown>;
  const reference = (value: unknown): value is string => typeof value === 'string' && uuid.test(value);
  if (!reference(input.request_id)) throw new Error('A valid request reference is required.');
  if (input.currency !== 'JMD') throw new Error('This ledger requires JMD amounts.');
  if (typeof input.memo !== 'string' || input.memo.trim().length < 5 || input.memo.length > 1000) throw new Error('Describe the posting.');
  if (typeof input.reason !== 'string' || input.reason.trim().length < 5 || input.reason.length > 500 || input.approved !== true) throw new Error('A decision reason and explicit posting approval are required.');
  if (!Array.isArray(input.lines) || input.lines.length < 2 || input.lines.length > 200) throw new Error('Provide between two and two hundred journal lines.');
  let debit = 0n, credit = 0n;
  const lines: JournalLine[] = input.lines.map((value: unknown) => {
    if (!value || typeof value !== 'object' || Array.isArray(value)) throw new Error('Invalid journal line.');
    const line = value as Record<string, unknown>;
    if (!reference(line.account_id)) throw new Error('Each line requires an account reference.');
    const amount = (value: unknown): value is number => typeof value === 'number' && Number.isSafeInteger(value) && value >= 0 && value <= maximumLineMinor;
    if (!amount(line.debit_minor) || !amount(line.credit_minor) || (line.debit_minor > 0) === (line.credit_minor > 0)) throw new Error('Each line requires exactly one positive debit or credit in whole minor units.');
    if (line.property_id != null && !reference(line.property_id)) throw new Error('Invalid property reference.');
    if (line.unit_id != null && (!reference(line.unit_id) || !reference(line.property_id))) throw new Error('A unit line requires its property reference.');
    debit += BigInt(line.debit_minor); credit += BigInt(line.credit_minor);
    return {account_id: line.account_id, debit_minor: line.debit_minor, credit_minor: line.credit_minor, property_id: line.property_id == null ? null : line.property_id as string, unit_id: line.unit_id == null ? null : line.unit_id as string};
  });
  if (debit !== credit) throw new Error('Total debits must equal total credits.');
  return {request_id: input.request_id, currency: 'JMD' as const, memo: input.memo.trim(), reason: input.reason.trim(), approved: true, lines, total_minor: debit.toString()};
}
