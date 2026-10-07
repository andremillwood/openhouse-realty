import {notFound, redirect} from 'next/navigation';
import {catalogAccess} from '@/lib/staff/access';
import {SiteHeader} from '@/components/discovery/site-header';
import {ReturnVisitEditor} from '@/components/staff/return-visit-editor';
import {CompletionEditor} from '@/components/staff/completion-editor';
import {CompletionSummary} from '@/components/staff/completion-summary';
import {EvidenceFiles} from '@/components/staff/evidence-files';
export const dynamic = 'force-dynamic';
export default async function Completion({params, searchParams}: {params: Promise<{workOrderId: string}>; searchParams: Promise<Record<string, string | string[] | undefined>>}) {
  const {client, user, membership} = await catalogAccess(['admin', 'manager']); if (!user) redirect('/sign-in'); if (!membership) notFound();
  const {workOrderId} = await params, input = await searchParams;
  const uuid = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
  if (!uuid.test(workOrderId)) notFound();
  const current = await client.from('work_orders').select('id,title,status,revision').eq('id', workOrderId).eq('organization_id', membership.organization_id).maybeSingle();
  if (current.error) throw new Error('Unable to load work order.'); if (!current.data) notFound();
  const reportId = typeof input.report === 'string' ? input.report : '';
  if (reportId && !uuid.test(reportId)) notFound();
  const selected = reportId ? await client.from('contractor_completion_reports').select('id,state,version,summary,tests_performed,outstanding_items,review_message,created_at,contractor_user_id,offer_id').eq('id', reportId).eq('work_order_id', workOrderId).eq('organization_id', membership.organization_id).maybeSingle() : null;
  if (selected?.error) throw new Error('Unable to load completion report.'); if (reportId && !selected?.data) notFound();
  const base = `/staff/work-orders/${workOrderId}/completion`;
  if (selected?.data) {
    const report = selected.data;
    const evidence = await client.from('contractor_evidence').select('id,file_name,state,expires_at,contractor_report_evidence!inner(report_id)').eq('organization_id', membership.organization_id).eq('contractor_report_evidence.report_id', report.id).eq('state', 'uploaded').order('id').limit(11);
    if (evidence.error || (evidence.data?.length || 0) > 10) throw new Error('Unable to load report evidence.');
    const correction = report.state === 'changes_requested' && current.data.status === 'in_progress' && report.contractor_user_id !== user.id;
    const assignment = correction ? await client.from('contractor_work_offers').select('id,version,state,work_version').eq('id', report.offer_id).eq('work_order_id', workOrderId).eq('organization_id', membership.organization_id).maybeSingle() : null;
    if (assignment?.error) throw new Error('Unable to load correction assignment.');
    const canReturn = correction && assignment?.data?.state === 'accepted' && assignment.data.work_version === current.data.revision;
    const canReview = report.state === 'submitted' && current.data.status === 'in_progress' && report.contractor_user_id !== user.id;
    return <><SiteHeader/><main className="account-layout"><section className="account-card"><p className="eyebrow">Independent completion review</p><h1>{current.data.title}</h1><CompletionSummary report={report}/><EvidenceFiles files={(evidence.data || []).map(file => ({id: file.id, file_name: file.file_name, state: file.state, expires_at: file.expires_at, frozen: true}))}/>{canReview ? <><CompletionEditor action="request_changes" reportId={report.id} version={report.version} returnTo={`${base}?report=${report.id}`}/><CompletionEditor action="approve" reportId={report.id} version={report.version} returnTo={`${base}?report=${report.id}`}/></> : <p>This report is not available for review by this account in its current state.</p>}{canReturn && assignment?.data && <ReturnVisitEditor reportId={report.id} reportVersion={report.version} offerVersion={assignment.data.version} workVersion={current.data.revision} returnTo={`/staff/work-orders/${workOrderId}/visits`}/>}<p><a href={`${base}/${report.id}/history`}>Private decision history</a></p><a href={base}>All completion reports</a></section></main></>;
  }
  const page = typeof input.page === 'string' && /^\d{1,5}$/.test(input.page) ? Math.max(1, Number(input.page)) : 1;
  const href = (next: number) => `${base}?page=${next}`;
  const query = (head = false) => client.from('contractor_completion_reports').select('id,state,created_at', {head, count: 'exact'}).eq('work_order_id', workOrderId).eq('organization_id', membership.organization_id);
  const count = await query(true); if (count.error) throw new Error('Unable to count completion reports.');
  const pages = Math.max(1, Math.ceil((count.count || 0)/25)); if (page > pages) redirect(href(pages));
  const rows = await query().order('created_at', {ascending: false}).order('id').range((page-1)*25, page*25-1);
  return <><SiteHeader/><main className="account-layout"><section className="account-card"><p className="eyebrow">Completion report queue</p><h1>{current.data.title}</h1>{rows.error ? <p role="alert">Unable to load reports. Please refresh.</p> : rows.data?.length ? rows.data.map(report => <article className="staff-editor" key={report.id}><h2><a href={`${base}?report=${report.id}`}>{report.state.replaceAll('_', ' ')}</a></h2><small>{new Date(report.created_at).toLocaleString('en-JM', {timeZone: 'America/Jamaica'})} (Jamaica time)</small></article>) : <p>No completion reports recorded.</p>}<nav className="results-toolbar" aria-label="Completion review pages">{page > 1 ? <a href={href(page-1)}>← Previous</a> : <span/>}<span>{count.count || 0} reports · Page {page} of {pages}</span>{page < pages ? <a href={href(page+1)}>Next →</a> : <span/>}</nav><a href={`/staff/work-orders/${workOrderId}`}>Back to work order</a></section></main></>;
}
