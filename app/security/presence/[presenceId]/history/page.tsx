import {notFound, redirect} from 'next/navigation';
import {createClient} from '@/lib/supabase/server';
import {SiteHeader} from '@/components/discovery/site-header';
export const dynamic = 'force-dynamic';
export default async function History({params, searchParams}: {params: Promise<{presenceId: string}>; searchParams: Promise<Record<string, string | string[] | undefined>>}) {
  const client = await createClient(), {data: {user}, error} = await client.auth.getUser();
  if (error || !user?.email_confirmed_at) redirect('/sign-in');
  const {presenceId} = await params, input = await searchParams;
  if (!/^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(presenceId)) notFound();
  const current = await client.from('contractor_presence').select('id,property_id,permit_id,state,checked_in_at,checked_out_at').eq('id', presenceId).maybeSingle();
  if (current.error) throw new Error('Unable to load presence.'); if (!current.data) notFound();
  const presence = current.data;
  const assignment = await client.from('property_security_assignments').select('id').eq('property_id', presence.property_id).eq('user_id', user.id).eq('is_active', true).maybeSingle();
  if (assignment.error) throw new Error('Unable to check security coverage.'); if (!assignment.data) notFound();
  const page = typeof input.page === 'string' && /^\d{1,5}$/.test(input.page) ? Math.max(1, Number(input.page)) : 1;
  const href = (next: number) => `/security/presence/${presenceId}/history?page=${next}`;
  const query = (head = false) => client.from('contractor_presence_changes').select('id,actor_user_id,action,new_state,version,reason,created_at', {head, count: 'exact'}).eq('property_id', presence.property_id).eq('presence_id', presence.id);
  const count = await query(true); if (count.error) throw new Error('Unable to count presence events.');
  const pages = Math.max(1, Math.ceil((count.count || 0)/25)); if (page > pages) redirect(href(pages));
  const rows = await query().order('created_at', {ascending: false}).order('id').range((page-1)*25, page*25-1);
  const time = (value: string) => new Date(value).toLocaleString('en-JM', {timeZone: 'America/Jamaica'});
  return <><SiteHeader/><main className="account-layout"><section className="account-card"><p className="eyebrow">Security presence history</p><h1>Arrival and departure record</h1><p>{presence.state} · Arrival {time(presence.checked_in_at)} (Jamaica time)</p>{presence.checked_out_at && <p>Departure {time(presence.checked_out_at)} (Jamaica time)</p>}{rows.error ? <p role="alert">Unable to load events. Please refresh.</p> : rows.data?.length ? rows.data.map(event => <article className="staff-editor" key={event.id}><h2>{event.action.replaceAll('_', ' ')} · Revision {event.version}</h2><p>{event.new_state}</p><p className="enquiry-message">{event.reason}</p><small>Recorded by {event.actor_user_id} · {time(event.created_at)} (Jamaica time)</small></article>) : <p>No events recorded.</p>}<nav className="results-toolbar" aria-label="Presence event pages">{page > 1 ? <a href={href(page-1)}>← Previous</a> : <span/>}<span>{count.count || 0} events · Page {page} of {pages}</span>{page < pages ? <a href={href(page+1)}>Next →</a> : <span/>}</nav><a href={`/security/entry/${presence.permit_id}`}>Back to permit</a></section></main></>;
}
