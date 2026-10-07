import {redirect} from 'next/navigation';
import {createClient} from '@/lib/supabase/server';
import {SiteHeader} from '@/components/discovery/site-header';
export const dynamic = 'force-dynamic';
export default async function WorkOffers({searchParams}: {searchParams: Promise<Record<string, string|string[]|undefined>>}) {
  const client = await createClient();
  const {data: {user}, error} = await client.auth.getUser();
  if (error || !user?.email_confirmed_at) redirect('/sign-in');
  const input = await searchParams;
  const state = typeof input.state === 'string' && ['offered','accepted','declined','withdrawn','expired'].includes(input.state) ? input.state : '';
  const page = typeof input.page === 'string' && /^\d{1,5}$/.test(input.page) ? Math.max(1, Number(input.page)) : 1;
  const href = (next: number) => `/account/work-offers?page=${next}${state ? `&state=${state}` : ''}`;
  const registrations = await client.from('contractor_accounts').select('id').eq('user_id', user.id).eq('is_active', true);
  if (registrations.error) throw new Error('Unable to load contractor access.');
  const ids = (registrations.data || []).map(row => row.id);
  if (!ids.length) return <><SiteHeader/><main className="account-layout"><section className="account-card"><h1>Your contractor work.</h1><p>No active contractor registration is linked to your verified account. Contact the Open House team about an approved registration.</p><a href="/account">Back to your account</a></section></main></>;
  const query = (head = false) => {let q = client.from('contractor_work_offers').select('id,job_title,trade,state,expires_at', {head, count: 'exact'}).in('contractor_id', ids); if (state) q = q.eq('state', state); return q;};
  const count = await query(true); if (count.error) throw new Error('Unable to count work offers.');
  const pages = Math.max(1, Math.ceil((count.count || 0)/25)); if (page > pages) redirect(href(pages));
  const rows = await query().order('created_at', {ascending: false}).order('id').range((page-1)*25, page*25-1);
  return <><SiteHeader/><main className="account-layout"><section className="account-card"><p className="eyebrow">Contractor workspace</p><h1>Your work offers.</h1><p>Review the approved scope before responding. Acceptance records your assignment. The team must arrange scheduling and entry separately.</p><form className="filter-bar" action="/account/work-offers"><label>Offer state<select name="state" defaultValue={state}><option value="">All states</option>{['offered','accepted','declined','withdrawn','expired'].map(value => <option key={value} value={value}>{value}</option>)}</select></label><button className="secondary">Apply filter</button></form>{rows.error ? <p role="alert">Unable to load offers. Please refresh.</p> : rows.data?.length ? rows.data.map(row => <article className="staff-editor" key={row.id}><h2><a href={`/account/work-offers/${row.id}`}>{row.job_title}</a></h2><p>{row.trade} · {row.state === 'offered' && Date.parse(row.expires_at) <= Date.now() ? 'expired' : row.state}</p></article>) : <p>No work offers in this view.</p>}<nav className="results-toolbar" aria-label="Work offer pages">{page > 1 ? <a href={href(page-1)}>← Previous</a> : <span/>}<span>{count.count || 0} offers · Page {page} of {pages}</span>{page < pages ? <a href={href(page+1)}>Next →</a> : <span/>}</nav><a href="/account">Back to your account</a></section></main></>;
}
