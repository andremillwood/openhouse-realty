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
  const visitId = typeof input.visit === 'string' ? input.visit : '';
  if (visitId && !uuid.test(visitId)) notFound();
  const selected = visitId ? await client.from('contractor_visits').select('id,starts_at,ends_at,shared_note,state,contractor_work_offers!inner(work_order_id)').eq('id', visitId).eq('contractor_work_offers.work_order_id', workOrderId).eq('organization_id', membership.organization_id).maybeSingle() : null;
  if (selected?.error) throw new Error('Unable to load appointment history.'); if (visitId && !selected?.data) notFound();
  const page = typeof input.page === 'string' && /^\d{1,5}$/.test(input.page) ? Math.max(1, Number(input.page)) : 1;
  const base = `/staff/work-orders/${workOrderId}/visits/history`, href = (next: number) => `${base}?page=${next}${visitId ? `&visit=${visitId}` : ''}`;
  const date = (value: string) => new Date(value).toLocaleString('en-JM', {timeZone: 'America/Jamaica'});
  if (selected?.data) {
    const visit = selected.data;
    const query = (head = false) => client.from('contractor_visit_changes').select('id,actor_user_id,action,previous_state,new_state,version,reason,created_at', {head, count: 'exact'}).eq('organization_id', membership.organization_id).eq('visit_id', visit.id);
    const count = await query(true); if (count.error) throw new Error('Unable to count appointment changes.');
    const pages = Math.max(1, Math.ceil((count.count || 0)/25)); if (page > pages) redirect(href(pages));
    const rows = await query().order('created_at', {ascending: false}).order('id').range((page-1)*25, page*25-1);
    return <><SiteHeader/><main className="account-layout"><section className="account-card"><p className="eyebrow">Private appointment audit</p><h1>{work.data.title}</h1><p>{visit.state} · {date(visit.starts_at)} → {date(visit.ends_at)} (Jamaica time)</p><p className="enquiry-message">{visit.shared_note}</p><h2>Recorded changes</h2>{rows.error ? <p role="alert">Unable to load changes. Please refresh.</p> : rows.data?.length ? rows.data.map(event => <article className="staff-editor" key={event.id}><h3>{event.action.replaceAll('_',' ')} · Revision {event.version}</h3><p>{event.previous_state || 'New appointment'} → {event.new_state}</p><p className="enquiry-message">{event.reason}</p><small>Actor: {event.actor_user_id || 'System'} · {date(event.created_at)} (Jamaica time)</small></article>) : <p>No recorded changes.</p>}<nav className="results-toolbar" aria-label="Appointment audit pages">{page > 1 ? <a href={href(page-1)}>← Previous</a> : <span/>}<span>{count.count || 0} changes · Page {page} of {pages}</span>{page < pages ? <a href={href(page+1)}>Next →</a> : <span/>}</nav><a href={base}>All appointments for this work order</a></section></main></>;
  }
  const query = (head = false) => client.from('contractor_visits').select('id,starts_at,ends_at,state,created_at,contractor_work_offers!inner(work_order_id)', {head, count: 'exact'}).eq('organization_id', membership.organization_id).eq('contractor_work_offers.work_order_id', workOrderId);
  const count = await query(true); if (count.error) throw new Error('Unable to count appointments.');
  const pages = Math.max(1, Math.ceil((count.count || 0)/25)); if (page > pages) redirect(href(pages));
  const rows = await query().order('created_at', {ascending: false}).order('id').range((page-1)*25, page*25-1);
  return <><SiteHeader/><main className="account-layout"><section className="account-card"><p className="eyebrow">Appointment history</p><h1>{work.data.title}</h1>{rows.error ? <p role="alert">Unable to load appointments. Please refresh.</p> : rows.data?.length ? rows.data.map(visit => <article className="staff-editor" key={visit.id}><h2><a href={`${base}?visit=${visit.id}`}>{visit.state}</a></h2><p>{date(visit.starts_at)} → {date(visit.ends_at)} (Jamaica time)</p><small>Proposed: {date(visit.created_at)} (Jamaica time)</small></article>) : <p>No appointments have been proposed for this work order.</p>}<nav className="results-toolbar" aria-label="Appointment history pages">{page > 1 ? <a href={href(page-1)}>← Previous</a> : <span/>}<span>{count.count || 0} appointments · Page {page} of {pages}</span>{page < pages ? <a href={href(page+1)}>Next →</a> : <span/>}</nav><a href={`/staff/work-orders/${workOrderId}/visits`}>Current appointment / scheduling</a></section></main></>;
}
