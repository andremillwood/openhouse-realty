export function statementQuery(input: Record<string, string | string[] | undefined>, today: string) {
  function date(value: unknown): value is string {return typeof value === 'string' && /^\d{4}-\d{2}-\d{2}$/.test(value) && !value.startsWith('0000') && Number.isFinite(Date.parse(`${value}T00:00:00Z`)) && new Date(`${value}T00:00:00Z`).toISOString().slice(0,10) === value;}
  const from = input.from === undefined ? `${today.slice(0,7)}-01` : input.from;
  const to = input.to === undefined ? today : input.to;
  if (!date(from) || !date(to) || from > to || (Date.parse(to)-Date.parse(from))/86400000 > 366) throw new Error('Choose valid dates spanning up to 367 inclusive days.');
  const page = typeof input.page === 'string' && /^\d{1,5}$/.test(input.page) ? Math.max(1, Number(input.page)) : 1;
  return {from, to, page};
}
