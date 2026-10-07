import {notFound, redirect} from 'next/navigation';
import {catalogAccess} from '@/lib/staff/access';
import {SiteHeader} from '@/components/discovery/site-header';
export const dynamic = 'force-dynamic';
export default async function History({params, searchParams}: {params: Promise<{workOrderId: string}>; searchParams: Promise<Record<string, string|string[]|undefined>>}) {
  const {client, user, membership} = await catalogAccess(['admin','manager']); if (!user) redirect('/sign-in'); if (!membership) notFound();
  const {workOrderId} = await params, input = await searchParams;
  const uuid = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
  if (!uuid.test(workOrderId)) notFound();
  const work = await client.from('work_orders').select('id,title').eq('id', workOrderId).eq('organization_id', membership.organization_id).maybeSingle();
  if (work.error) throw new Error('Unable to load work order.'); if (!work.data) notFound();
  const offerId = typeof input.offer === 'string' ? input.offer : '';
  if (offerId && !uuid.test(offerId)) notFound();
  const selected = offerId ? await client.from('contractor_work_offers').select('id,job_title,scope_summary,company_name_snapshot,trade,state,expires_at').eq('id', offerId).eq('work_order_id', workOrderId).eq('organization_id', membership.organization_id).maybeSingle() : null;
  if (selected?.error) throw new Error('Unable to load offer history.'); if (offerId && !selected?.data) notFound();
  const page = typeof input.page === 'string' && /^\d{1,5}$/.test(input.page) ? Math.max(1, Number(input.page)) : 1;
  const base = `/staff/work-orders/${workOrderId}/offers/history`, href = (next: number) => `${base}?page=${next}${offerId ? `&offer=${offerId}` : ''}`;
  const date = (value: string) => new Date(value).toLocaleString('en-JM', {timeZone: 'America/Jamaica'});
  if (selected?.data) {
    const offer = selected.data;
    const query = (head = false) => client.from('contractor_work_offer_changes').select('id,actor_user_id,action,previous_state,new_state,version,reason,created_at', {head, count: 'exact'}).eq('organization_id', membership.organization_id).eq('offer_id', offer.id);
    const count = await query(true); if (count.error) throw new Error('Unable to count offer changes.');
    const pages = Math.max(1, Math.ceil((count.count || 0)/25)); if (page > pages) redirect(href(pages));
    const rows = await query().order('created_at', {ascending: false}).order('id').range((page-1)*25, page*25-1);
    return <><SiteHeader/><main className="account-layout"><section className="account-card"><p className="eyebrow">Private offer audit</p><h1>{offer.job_title}</h1><p>{offer.company_name_snapshot} · {offer.trade} · {offer.state === 'offered' && Date.parse(offer.expires_at) <= Date.now() ? 'expired, awaiting recorded transition' : offer.state}</p><p className="enquiry-message">{offer.scope_summary}</p><h2>Recorded changes</h2>{rows.error ? <p role="alert">Unable to load changes. Please refresh.</p> : rows.data?.length ? rows.data.map(event => <article className="staff-editor" key={event.id}><h3>{event.action.replaceAll('_',' ')} · Revision {event.version}</h3><p>{event.previous_state || 'New offer'} → {event.new_state}</p><p className="enquiry-message">{event.reason}</p><small>Actor: {event.actor_user_id || 'System'} · {date(event.created_at)} (Jamaica time)</small></article>) : <p>No recorded changes.</p>}<nav className="results-toolbar" aria-label="Offer audit pages">{page > 1 ? <a href={href(page-1)}>← Previous</a> : <span/>}<span>{count.count || 0} changes · Page {page} of {pages}</span>{page < pages ? <a href={href(page+1)}>Next →</a> : <span/>}</nav><a href={base}>All offers for this work order</a></section></main></>;
  }
  const query = (head = false) => client.from('contractor_work_offers').select('id,job_title,company_name_snapshot,trade,state,expires_at,created_at', {head, count: 'exact'}).eq('organization_id', membership.organization_id).eq('work_order_id', workOrderId);
  const count = await query(true); if (count.error) throw new Error('Unable to count offers.');
  const pages = Math.max(1, Math.ceil((count.count || 0)/25)); if (page > pages) redirect(href(pages));
  const rows = await query().order('created_at', {ascending: false}).order('id').range((page-1)*25, page*25-1);
  return <><SiteHeader/><main className="account-layout"><section className="account-card"><p className="eyebrow">Work offer history</p><h1>{work.data.title}</h1>{rows.error ? <p role="alert">Unable to load offers. Please refresh.</p> : rows.data?.length ? rows.data.map(offer => <article className="staff-editor" key={offer.id}><h2><a href={`${base}?offer=${offer.id}`}>{offer.job_title}</a></h2><p>{offer.company_name_snapshot} · {offer.trade} · {offer.state === 'offered' && Date.parse(offer.expires_at) <= Date.now() ? 'expired, awaiting recorded transition' : offer.state}</p><small>{date(offer.created_at)} (Jamaica time)</small></article>) : <p>No offers have been created for this work order.</p>}<nav className="results-toolbar" aria-label="Work offer history pages">{page > 1 ? <a href={href(page-1)}>← Previous</a> : <span/>}<span>{count.count || 0} offers · Page {page} of {pages}</span>{page < pages ? <a href={href(page+1)}>Next →</a> : <span/>}</nav><a href={`/staff/work-orders/${workOrderId}/offers`}>Current offer / contractor selection</a></section></main></>;
}
