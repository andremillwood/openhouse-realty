import {notFound, redirect} from 'next/navigation';
import {createClient} from '@/lib/supabase/server';
import {SiteHeader} from '@/components/discovery/site-header';
import {CompletionEditor} from '@/components/staff/completion-editor';
import {CompletionSummary} from '@/components/staff/completion-summary';
export const dynamic = 'force-dynamic';
export default async function Completion({params, searchParams}: {params: Promise<{offerId: string}>; searchParams: Promise<Record<string, string | string[] | undefined>>}) {
  const client = await createClient(), {data: {user}, error} = await client.auth.getUser();
  if (error || !user?.email_confirmed_at) redirect('/sign-in');
  const {offerId} = await params, input = await searchParams;
  if (!/^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(offerId)) notFound();
  const registrations = await client.from('contractor_accounts').select('id').eq('user_id', user.id).eq('is_active', true);
  if (registrations.error) throw new Error('Unable to load contractor access.');
  const ids = (registrations.data || []).map(row => row.id); if (!ids.length) notFound();
  const current = await client.from('contractor_work_offers').select('id,job_title,state,version').eq('id', offerId).in('contractor_id', ids).maybeSingle();
  if (current.error) throw new Error('Unable to load assignment.'); if (!current.data) notFound();
  const offer = current.data;
  const pending = await client.from('contractor_completion_reports').select('id').eq('offer_id', offerId).eq('contractor_user_id', user.id).eq('state', 'submitted').maybeSingle();
  if (pending.error) throw new Error('Unable to check pending completion review.');
  const presence = offer.state === 'accepted' ? await client.from('contractor_presence').select('state,contractor_visits!inner(offer_id)').eq('contractor_user_id', user.id).eq('contractor_visits.offer_id', offerId).order('checked_in_at', {ascending: false}).order('id').limit(1) : null;
  if (presence?.error) throw new Error('Unable to check departure.');
  const page = typeof input.page === 'string' && /^\d{1,5}$/.test(input.page) ? Math.max(1, Number(input.page)) : 1;
  const base = `/account/work-offers/${offerId}/completion`, href = (next: number) => `${base}?page=${next}`;
  const query = (head = false) => client.from('contractor_completion_reports').select('id,state,version,summary,tests_performed,outstanding_items,review_message,created_at', {head, count: 'exact'}).eq('offer_id', offerId).eq('contractor_user_id', user.id);
  const count = await query(true); if (count.error) throw new Error('Unable to count completion reports.');
  const pages = Math.max(1, Math.ceil((count.count || 0)/25)); if (page > pages) redirect(href(pages));
  const rows = await query().order('created_at', {ascending: false}).order('id').range((page-1)*25, page*25-1);
  return <><SiteHeader/><main className="account-layout"><section className="account-card"><p className="eyebrow">Contractor completion</p><h1>{offer.job_title}</h1><p><a href={`/account/work-offers/${offerId}/evidence`}>Upload and review private evidence</a></p><p>Submitting a report includes all verified uploaded files for this assignment. Check them before submitting; included files remain fixed.</p>{offer.state === 'accepted' && !pending.data && presence?.data?.[0]?.state === 'exited' ? <CompletionEditor action="submit" offerId={offerId} offerVersion={offer.version} returnTo={base}/> : <p>{pending.data ? 'Your report is awaiting management review.' : offer.state === 'completed' ? 'Management approved completion.' : 'Security must record departure before you submit a completion report.'}</p>}<h2>Submitted reports and feedback</h2>{rows.error ? <p role="alert">Unable to load reports. Please refresh.</p> : rows.data?.length ? rows.data.map(report => <CompletionSummary key={report.id} report={report}/>) : <p>No completion reports recorded.</p>}<nav className="results-toolbar" aria-label="Completion report pages">{page > 1 ? <a href={href(page-1)}>← Previous</a> : <span/>}<span>{count.count || 0} reports · Page {page} of {pages}</span>{page < pages ? <a href={href(page+1)}>Next →</a> : <span/>}</nav><a href={`/account/work-offers/${offerId}`}>Back to assignment</a></section></main></>;
}
