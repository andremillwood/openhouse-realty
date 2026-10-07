import {notFound, redirect} from 'next/navigation';
import {catalogAccess} from '@/lib/staff/access';
import {SiteHeader} from '@/components/discovery/site-header';
import {EntryPermitEditor} from '@/components/staff/entry-permit-editor';
import {EntryPermitSummary} from '@/components/staff/entry-permit-summary';
import {VisitSummary} from '@/components/staff/visit-summary';
export const dynamic = 'force-dynamic';
export default async function Entry({params}: {params: Promise<{workOrderId: string}>}) {
  const {client, user, membership} = await catalogAccess(['admin','manager']); if (!user) redirect('/sign-in'); if (!membership) notFound();
  const {workOrderId} = await params; if (!/^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(workOrderId)) notFound();
  const order = await client.from('work_orders').select('id,title,status').eq('id', workOrderId).eq('organization_id', membership.organization_id).maybeSingle();
  if (order.error) throw new Error('Unable to load work order.'); if (!order.data) notFound();
  const offer = await client.from('contractor_work_offers').select('id').eq('work_order_id', workOrderId).eq('organization_id', membership.organization_id).eq('state','accepted').maybeSingle();
  if (offer.error) throw new Error('Unable to load assignment.');
  const visit = offer.data ? await client.from('contractor_visits').select('id,state,version,starts_at,ends_at,shared_note').eq('offer_id', offer.data.id).eq('organization_id', membership.organization_id).eq('state','confirmed').maybeSingle() : null;
  if (visit?.error) throw new Error('Unable to load confirmed visit.');
  const permit = visit?.data ? await client.from('contractor_entry_permits').select('id,state,version,valid_from,valid_until,shared_instructions').eq('visit_id', visit.data.id).eq('organization_id', membership.organization_id).eq('state','authorized').maybeSingle() : null;
  if (permit?.error) throw new Error('Unable to load entry authorization.');
  const returnTo = `/staff/work-orders/${workOrderId}/entry`;
  return <><SiteHeader/><main className="account-layout"><section className="account-card"><p className="eyebrow">Management access decision</p><h1>{order.data.title}</h1>{!visit?.data ? <p>A confirmed contractor appointment is required before authorizing entry.</p> : <><VisitSummary visit={visit.data}/>{permit?.data ? <><EntryPermitSummary permit={permit.data}/><EntryPermitEditor action="revoke" permitId={permit.data.id} version={permit.data.version} returnTo={returnTo}/></> : order.data.status === 'scheduled' && Date.parse(visit.data.ends_at) > Date.now() ? <EntryPermitEditor action="authorize" visit={visit.data} returnTo={returnTo}/> : <p>The current work stage or elapsed appointment does not permit a new entry authorization.</p>}</>}<p><a href={`/staff/work-orders/${workOrderId}/entry/history`}>Entry decision history ↗</a></p><a href={`/staff/work-orders/${workOrderId}/visits`}>Back to visit scheduling</a></section></main></>;
}
