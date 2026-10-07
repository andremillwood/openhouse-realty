/** Parse decimal JMD directly into integer cents without floating point multiplication. */
export function jmdMinor(value: string): number {
  const text = value.trim();
  if (!/^(0|[1-9]\d{0,11})(\.\d{1,2})?$/.test(text)) throw new Error('Enter a JMD amount with up to two decimal places, without commas.');
  const [whole, fraction = ''] = text.split('.');
  const cents = BigInt(whole) * 100n + BigInt(fraction.padEnd(2, '0'));
  if (cents > 99999999999999n) throw new Error('Amount exceeds the journal line limit.');
  return Number(cents);
}
export function formatJmdMinor(value: string | bigint): string {
  const amount = BigInt(value); const sign = amount < 0n ? '-' : ''; const positive = amount < 0n ? -amount : amount;
  return `${sign}JMD ${(positive / 100n).toLocaleString('en-JM')}.${(positive % 100n).toString().padStart(2, '0')}`;
}
