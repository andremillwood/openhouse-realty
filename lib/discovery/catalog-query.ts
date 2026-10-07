export const CATALOG_PAGE_SIZE = 24;
type Search = Record<string, string | string[] | undefined>;
const single = (value: string | string[] | undefined) => typeof value === 'string' ? value : '';
// Strip PostgREST filter syntax and LIKE wildcards from user search text.
const searchText = (value: string) => value.replace(/[^\p{L}\p{N}\s'-]/gu, ' ').replace(/\s+/g, ' ').trim().slice(0, 120);
export function catalogQuery(input: Search) {
  const rawPage = single(input.page);
  const page = /^\d{1,6}$/.test(rawPage) ? Math.max(1, Math.min(100000, Number(rawPage))) : 1;
  const rawIntent = single(input.intent);
  return { page, q: searchText(single(input.q)), area: searchText(single(input.area)), intent: rawIntent === 'sale' || rawIntent === 'rent' ? rawIntent : 'all' };
}
export function catalogHref(filters: ReturnType<typeof catalogQuery>, page: number) {
  const query = new URLSearchParams();
  if (filters.q) query.set('q', filters.q);
  if (filters.area) query.set('area', filters.area);
  if (filters.intent !== 'all') query.set('intent', filters.intent);
  if (page > 1) query.set('page', String(page));
  return `/listings${query.size ? `?${query}` : ''}`;
}
