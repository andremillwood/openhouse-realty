import {notFound, redirect} from 'next/navigation';
import {catalogAccess} from '@/lib/staff/access';
import {SiteHeader} from '@/components/discovery/site-header';
import {WorkOfferEditor} from '@/components/staff/work-offer-editor';
import {WorkOfferResponse} from '@/components/staff/work-offer-response';
export const dynamic = 'force-dynamic';
export default async function Offers({params, searchParams}: {params: Promise<{workOrderId: string}>; searchParams: Promise<Record<string, string|string[]|undefined>>}) {
  const {client, user, membership} = await catalogAccess(['admin','manager']); if (!user) redirect('/sign-in'); if (!membership) notFound();
  const {workOrderId} = await params, input = await searchParams;
  const uuid = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
  if (!uuid.test(workOrderId)) notFound();
  const order = await client.from('work_orders').select('id,title,status,revision').eq('id', workOrderId).eq('organization_id', membership.organization_id).maybeSingle();
  if (order.error) throw new Error('Unable to load work order.'); if (!order.data) notFound();
  const base = `/staff/work-orders/${workOrderId}/offers`;
  const active = await client.from('contractor_work_offers').select('id,job_title,scope_summary,company_name_snapshot,trade,state,version,expires_at').eq('organization_id', membership.organization_id).eq('work_order_id', workOrderId).in('state', ['offered','accepted']).maybeSingle();
  if (active.error) throw new Error('Unable to load current offer.');
  const actionable = active.data && (active.data.state === 'accepted' || Date.parse(active.data.expires_at) > Date.now());
  if (actionable) {const offer = active.data!;return <><SiteHeader/><main className="account-layout"><section className="account-card"><h1>{order.data.title}</h1><h2>{offer.job_title}</h2><p>{offer.company_name_snapshot} · {offer.trade} · {offer.state}</p><p className="enquiry-message">{offer.scope_summary}</p><p>Acceptance assigns the work. Scheduling and entry authorization remain separate.</p><WorkOfferResponse offerId={offer.id} version={offer.version} action="withdraw" returnTo={base}/><a href={`/staff/work-orders/${workOrderId}`}>Back to work order</a></section></main></>;}
  if (order.data.status !== 'triaged') return <><SiteHeader/><main className="account-layout"><section className="account-card"><h1>{order.data.title}</h1><p>Work must be triaged before a contractor offer can be created.</p><a href={`/staff/work-orders/${workOrderId}`}>Back to work order</a></section></main></>;
  const selectedId = typeof input.contractor === 'string' ? input.contractor : '';
  if (selectedId && !uuid.test(selectedId)) notFound();
  const selected = selectedId ? await client.from('contractor_accounts').select('id,company_name,trade_coverage').eq('id', selectedId).eq('organization_id', membership.organization_id).eq('is_active', true).maybeSingle() : null;
  if (selected?.error) throw new Error('Unable to load selected contractor.'); if (selectedId && !selected?.data) notFound();
  const page = typeof input.page === 'string' && /^\d{1,5}$/.test(input.page) ? Math.max(1, Number(input.page)) : 1;
  const href = (next: number) => `${base}?page=${next}${selectedId ? `&contractor=${selectedId}` : ''}`;
  const query = (head = false) => client.from('contractor_accounts').select('id,company_name,trade_coverage', {head, count: 'exact'}).eq('organization_id', membership.organization_id).eq('is_active', true);
  const count = await query(true); if (count.error) throw new Error('Unable to count contractors.'); const pages = Math.max(1, Math.ceil((count.count || 0)/25)); if (page > pages) redirect(href(pages));
  const rows = await query().order('company_name').order('id').range((page-1)*25, page*25-1);
  return <><SiteHeader/><main className="account-layout"><section className="account-card"><p className="eyebrow">Contractor assignment</p><h1>{order.data.title}</h1><p>Select an active approved contractor, then approve the scope to share. The contractor must accept before work is assigned.</p>{active.data && <p>The previous pending offer has expired. A new approved offer can replace it.</p>}{selected?.data && <WorkOfferEditor workOrderId={order.data.id} workVersion={order.data.revision} contractor={selected.data}/>}<h2>Choose a contractor</h2>{rows.error ? <p role="alert">Unable to load contractors. Please refresh.</p> : rows.data?.length ? rows.data.map(row => <article className="staff-editor" key={row.id}><h3>{row.company_name}</h3><p>{row.trade_coverage.join(' · ')}</p><a href={`${base}?contractor=${row.id}`}>Select contractor →</a></article>) : <p>No active approved contractors. <a href="/staff/contractors">Open contractor register</a></p>}<nav className="results-toolbar" aria-label="Contractor selection pages">{page > 1 ? <a href={href(page-1)}>← Previous</a> : <span/>}<span>{count.count || 0} contractors · Page {page} of {pages}</span>{page < pages ? <a href={href(page+1)}>Next →</a> : <span/>}</nav><a href={`/staff/work-orders/${workOrderId}`}>Back to work order</a></section></main></>;
}
