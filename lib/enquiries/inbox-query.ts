export const INBOX_PAGE_SIZE = 25;
type Params = Record<string, string | string[] | undefined>;
export function inboxQuery(params: Params) {
  const status = typeof params.status === 'string' && ['new','contacted','closed'].includes(params.status) ? params.status : 'all';
  const raw = typeof params.page === 'string' ? params.page : '';
  const page = /^\d{1,6}$/.test(raw) ? Math.max(1, Math.min(100000, Number(raw))) : 1;
  return { status, page };
}
export function inboxHref(filters: ReturnType<typeof inboxQuery>, page: number) {
  const query = new URLSearchParams();
  if (filters.status !== 'all') query.set('status', filters.status);
  if (page > 1) query.set('page', String(page));
  return `/staff/enquiries${query.size ? `?${query}` : ''}`;
}
