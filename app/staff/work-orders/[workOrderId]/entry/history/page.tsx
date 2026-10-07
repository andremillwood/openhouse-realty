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
  const permitId = typeof input.permit === 'string' ? input.permit : '';
  if (permitId && !uuid.test(permitId)) notFound();
  const selected = permitId ? await client.from('contractor_entry_permits').select('id,valid_from,valid_until,shared_instructions,state,contractor_visits!inner(contractor_work_offers!inner(work_order_id))').eq('id', permitId).eq('contractor_visits.contractor_work_offers.work_order_id', workOrderId).eq('organization_id', membership.organization_id).maybeSingle() : null;
  if (selected?.error) throw new Error('Unable to load authorization history.'); if (permitId && !selected?.data) notFound();
  const page = typeof input.page === 'string' && /^\d{1,5}$/.test(input.page) ? Math.max(1, Number(input.page)) : 1;
  const base = `/staff/work-orders/${workOrderId}/entry/history`, href = (next: number) => `${base}?page=${next}${permitId ? `&permit=${permitId}` : ''}`;
  const date = (value: string) => new Date(value).toLocaleString('en-JM', {timeZone: 'America/Jamaica'});
  if (selected?.data) {
    const permit = selected.data;
    const query = (head = false) => client.from('contractor_entry_permit_changes').select('id,actor_user_id,action,previous_state,new_state,version,reason,created_at', {head, count: 'exact'}).eq('organization_id', membership.organization_id).eq('permit_id', permit.id);
    const count = await query(true); if (count.error) throw new Error('Unable to count authorization changes.');
    const pages = Math.max(1, Math.ceil((count.count || 0)/25)); if (page > pages) redirect(href(pages));
    const rows = await query().order('created_at', {ascending: false}).order('id').range((page-1)*25, page*25-1);
    return <><SiteHeader/><main className="account-layout"><section className="account-card"><p className="eyebrow">Private authorization audit</p><h1>{work.data.title}</h1><p>{permit.state} · {date(permit.valid_from)} → {date(permit.valid_until)} (Jamaica time)</p><p className="enquiry-message">{permit.shared_instructions}</p><h2>Recorded changes</h2>{rows.error ? <p role="alert">Unable to load changes. Please refresh.</p> : rows.data?.length ? rows.data.map(event => <article className="staff-editor" key={event.id}><h3>{event.action.replaceAll('_',' ')} · Revision {event.version}</h3><p>{event.previous_state || 'New authorization'} → {event.new_state}</p><p className="enquiry-message">{event.reason}</p><small>Actor: {event.actor_user_id || 'System'} · {date(event.created_at)} (Jamaica time)</small></article>) : <p>No recorded changes.</p>}<nav className="results-toolbar" aria-label="Authorization audit pages">{page > 1 ? <a href={href(page-1)}>← Previous</a> : <span/>}<span>{count.count || 0} changes · Page {page} of {pages}</span>{page < pages ? <a href={href(page+1)}>Next →</a> : <span/>}</nav><a href={base}>All authorizations for this work order</a></section></main></>;
  }
  const query = (head = false) => client.from('contractor_entry_permits').select('id,valid_from,valid_until,state,created_at,contractor_visits!inner(contractor_work_offers!inner(work_order_id))', {head, count: 'exact'}).eq('organization_id', membership.organization_id).eq('contractor_visits.contractor_work_offers.work_order_id', workOrderId);
  const count = await query(true); if (count.error) throw new Error('Unable to count authorizations.');
  const pages = Math.max(1, Math.ceil((count.count || 0)/25)); if (page > pages) redirect(href(pages));
  const rows = await query().order('created_at', {ascending: false}).order('id').range((page-1)*25, page*25-1);
  return <><SiteHeader/><main className="account-layout"><section className="account-card"><p className="eyebrow">Authorization history</p><h1>{work.data.title}</h1>{rows.error ? <p role="alert">Unable to load authorizations. Please refresh.</p> : rows.data?.length ? rows.data.map(permit => <article className="staff-editor" key={permit.id}><h2><a href={`${base}?permit=${permit.id}`}>{permit.state}</a></h2><p>{date(permit.valid_from)} → {date(permit.valid_until)} (Jamaica time)</p><small>Recorded: {date(permit.created_at)} (Jamaica time)</small></article>) : <p>No authorizations have been recorded for this work order.</p>}<nav className="results-toolbar" aria-label="Authorization history pages">{page > 1 ? <a href={href(page-1)}>← Previous</a> : <span/>}<span>{count.count || 0} authorizations · Page {page} of {pages}</span>{page < pages ? <a href={href(page+1)}>Next →</a> : <span/>}</nav><a href={`/staff/work-orders/${workOrderId}/entry`}>Current entry authorization</a></section></main></>;
}
