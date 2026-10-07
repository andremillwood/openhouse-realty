export function jamaicaTimestamp(value: string) {
  if (!/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}$/.test(value)) throw new Error('Enter a valid date and time in Jamaica time.');
  const date = new Date(`${value}:00-05:00`);
  if (!Number.isFinite(date.getTime()) || new Date(date.getTime()-5*60*60*1000).toISOString().slice(0,16) !== value) throw new Error('Enter a valid date and time in Jamaica time.');
  return date.toISOString();
}
