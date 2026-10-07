import {notFound, redirect} from 'next/navigation';
import {createClient} from '@/lib/supabase/server';
import {SiteHeader} from '@/components/discovery/site-header';
import {WorkOfferResponse} from '@/components/staff/work-offer-response';
import {VisitEditor} from '@/components/staff/visit-editor';
import {VisitSummary} from '@/components/staff/visit-summary';
import {EntryPermitSummary} from '@/components/staff/entry-permit-summary';
export const dynamic = 'force-dynamic';
export default async function Offer({params}: {params: Promise<{offerId: string}>}) {
  const client = await createClient(); const {data: {user}, error} = await client.auth.getUser();
  if (error || !user?.email_confirmed_at) redirect('/sign-in');
  const {offerId} = await params;
  if (!/^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(offerId)) notFound();
  const registrations = await client.from('contractor_accounts').select('id').eq('user_id', user.id).eq('is_active', true);
  if (registrations.error) throw new Error('Unable to load contractor access.');
  const ids = (registrations.data || []).map(row => row.id); if (!ids.length) notFound();
  const result = await client.from('contractor_work_offers').select('id,job_title,scope_summary,trade,company_name_snapshot,state,version,expires_at').eq('id', offerId).in('contractor_id', ids).maybeSingle();
  if (result.error) throw new Error('Unable to load this work offer.'); if (!result.data) notFound();
  const offer = result.data, expired = offer.state === 'offered' && Date.parse(offer.expires_at) <= Date.now();
  const current = offer.state === 'accepted' ? await client.from('contractor_visits').select('id,state,version,starts_at,ends_at,shared_note').eq('offer_id', offer.id).eq('contractor_user_id', user.id).in('state',['proposed','confirmed']).maybeSingle() : null;
  if (current?.error) throw new Error('Unable to load current appointment.');
  const permit = current?.data?.state === 'confirmed' ? await client.from('contractor_entry_permits').select('id,state,valid_from,valid_until,shared_instructions').eq('visit_id', current.data.id).eq('contractor_user_id', user.id).eq('state','authorized').maybeSingle() : null;
  if (permit?.error) throw new Error('Unable to load entry authorization.');
  const returnTo = `/account/work-offers/${offer.id}`;
  return <><SiteHeader/><main className="account-layout"><section className="account-card"><p className="eyebrow">Approved work scope</p><h1>{offer.job_title}</h1><p>{offer.company_name_snapshot} · {offer.trade}</p><p>State: {expired ? 'expired' : offer.state}</p><p className="enquiry-message">{offer.scope_summary}</p><p>Offer expires: {new Date(offer.expires_at).toLocaleString('en-JM', {timeZone: 'America/Jamaica'})} (Jamaica time)</p><p>Acceptance confirms your assignment. Contact the team to arrange a visit; this offer does not authorize entry.</p>{offer.state === 'offered' && !expired && <><WorkOfferResponse offerId={offer.id} version={offer.version} action="accept" returnTo={returnTo}/><WorkOfferResponse offerId={offer.id} version={offer.version} action="decline" returnTo={returnTo}/></>}{current?.data && <><VisitSummary visit={current.data}/>{permit?.data ? <EntryPermitSummary permit={permit.data}/> : current.data.state === 'confirmed' && <p>Entry has not been authorized. Contact management before visiting.</p>}{current.data.state === 'proposed' && Date.parse(current.data.starts_at) > Date.now() && <VisitEditor action="confirm" visitId={current.data.id} version={current.data.version} returnTo={returnTo}/ >}{current.data.state === 'proposed' && <VisitEditor action="decline" visitId={current.data.id} version={current.data.version} returnTo={returnTo}/>}<VisitEditor action="cancel" visitId={current.data.id} version={current.data.version} returnTo={returnTo}/></>}{offer.state === 'accepted' && !current?.data && <WorkOfferResponse offerId={offer.id} version={offer.version} action="release" returnTo={returnTo}/>}<p><a href={`/account/work-offers/${offer.id}/completion`}>Completion reports and feedback</a> · <a href={`/account/work-offers/${offer.id}/evidence`}>Private evidence files</a></p><a href="/account/work-offers">Back to work offers</a></section></main></>;
}
