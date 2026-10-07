import {notFound, redirect} from 'next/navigation';
import {createClient} from '@/lib/supabase/server';
import {SiteHeader} from '@/components/discovery/site-header';
import {PresenceEditor} from '@/components/security/presence-editor';
export const dynamic = 'force-dynamic';
type Snapshot = {permit_id: string; property_name: string; company_name: string; job_title: string; shared_instructions: string; permit_state: string; valid_from: string; valid_until: string; entry_allowed: boolean; presence_id: string | null; presence_state: string | null; presence_version: number | null; checked_in_at: string | null; checked_out_at: string | null};
export default async function Entry({params}: {params: Promise<{permitId: string}>}) {
  const client = await createClient(), {data: {user}, error: authError} = await client.auth.getUser();
  if (authError || !user?.email_confirmed_at) redirect('/sign-in');
  const {permitId} = await params;
  if (!/^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(permitId)) notFound();
  const {data, error} = await client.rpc('security_entry_snapshot', {p_permit_id: permitId});
  if (error?.code === '42501' || !data && !error) notFound();
  if (error) throw new Error('Unable to check this entry permit.');
  const snapshot = data as Snapshot;
  const time = (value: string) => new Date(value).toLocaleString('en-JM', {timeZone: 'America/Jamaica'});
  return <><SiteHeader/><main className="account-layout"><section className="account-card"><p className="eyebrow">Gatehouse entry</p><h1>{snapshot.property_name}</h1><h2>{snapshot.company_name}</h2><p>{snapshot.job_title}</p><p>Permit reference: {snapshot.permit_id}</p><p>Permit: {snapshot.permit_state} · {time(snapshot.valid_from)} to {time(snapshot.valid_until)} (Jamaica time)</p><p className="enquiry-message">{snapshot.shared_instructions}</p>{snapshot.checked_in_at && <p>Arrival: {time(snapshot.checked_in_at)} (Jamaica time)</p>}{snapshot.checked_out_at && <p>Departure: {time(snapshot.checked_out_at)} (Jamaica time)</p>}{snapshot.presence_state === 'on_site' && snapshot.presence_id && snapshot.presence_version ? <PresenceEditor permitId={permitId} presenceId={snapshot.presence_id} version={snapshot.presence_version}/> : snapshot.entry_allowed ? <><p>Permit is currently eligible for entry. Check the visitor’s identity before recording arrival.</p><PresenceEditor permitId={permitId}/></> : <p>{snapshot.presence_state === 'exited' ? 'Departure recorded. A new appointment and permit are required for another visit.' : 'Entry is unavailable. Contact property management to review the appointment or permit.'}</p>}<p>Recording departure does not approve or complete the contractor’s work.</p>{snapshot.presence_id && <p><a href={`/security/presence/${snapshot.presence_id}/history`}>Arrival and departure history</a></p>}<a href="/security">Check another permit</a></section></main></>;
}
