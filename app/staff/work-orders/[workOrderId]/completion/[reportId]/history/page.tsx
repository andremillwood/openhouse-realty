import {notFound, redirect} from 'next/navigation';
import {catalogAccess} from '@/lib/staff/access';
import {SiteHeader} from '@/components/discovery/site-header';
export const dynamic = 'force-dynamic';
export default async function History({params, searchParams}: {params: Promise<{workOrderId: string; reportId: string}>; searchParams: Promise<Record<string, string | string[] | undefined>>}) {
  const {client, user, membership} = await catalogAccess(['admin', 'manager']);
  if (!user) redirect('/sign-in'); if (!membership) notFound();
  const {workOrderId, reportId} = await params, input = await searchParams;
  const uuid = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
  if (!uuid.test(workOrderId) || !uuid.test(reportId)) notFound();
  const work = await client.from('work_orders').select('id,title').eq('id', workOrderId).eq('organization_id', membership.organization_id).maybeSingle();
  if (work.error) throw new Error('Unable to load work order.'); if (!work.data) notFound();
  const report = await client.from('contractor_completion_reports').select('id,state,version').eq('id', reportId).eq('work_order_id', workOrderId).eq('organization_id', membership.organization_id).maybeSingle();
  if (report.error) throw new Error('Unable to load report.'); if (!report.data) notFound();
  const page = typeof input.page === 'string' && /^\d{1,5}$/.test(input.page) ? Math.max(1, Number(input.page)) : 1;
  const href = (next: number) => `/staff/work-orders/${workOrderId}/completion/${reportId}/history?page=${next}`;
  const query = (head = false) => client.from('contractor_completion_changes').select('id,actor_user_id,action,previous_state,new_state,version,reason,created_at', {head, count: 'exact'}).eq('organization_id', membership.organization_id).eq('report_id', reportId);
  const count = await query(true); if (count.error) throw new Error('Unable to count report changes.');
  const pages = Math.max(1, Math.ceil((count.count || 0)/25)); if (page > pages) redirect(href(pages));
  const rows = await query().order('created_at', {ascending: false}).order('id').range((page-1)*25, page*25-1);
  const time = (value: string) => new Date(value).toLocaleString('en-JM', {timeZone: 'America/Jamaica'});
  return <><SiteHeader/><main className="account-layout"><section className="account-card"><p className="eyebrow">Private completion audit</p><h1>{work.data.title}</h1><p>Report: {report.data.state.replaceAll('_', ' ')} · Revision {report.data.version}</p>{rows.error ? <p role="alert">Unable to load changes. Please refresh.</p> : rows.data?.length ? rows.data.map(event => <article className="staff-editor" key={event.id}><h2>{event.action.replaceAll('_', ' ')} · Revision {event.version}</h2><p>{event.previous_state || 'New report'} → {event.new_state}</p><p className="enquiry-message">{event.reason}</p><small>Actor: {event.actor_user_id} · {time(event.created_at)} (Jamaica time)</small></article>) : <p>No recorded changes.</p>}<nav className="results-toolbar" aria-label="Completion audit pages">{page > 1 ? <a href={href(page-1)}>← Previous</a> : <span/>}<span>{count.count || 0} changes · Page {page} of {pages}</span>{page < pages ? <a href={href(page+1)}>Next →</a> : <span/>}</nav><a href={`/staff/work-orders/${workOrderId}/completion?report=${reportId}`}>Back to report review</a></section></main></>;
}
