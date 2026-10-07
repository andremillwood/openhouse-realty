import {notFound, redirect} from 'next/navigation';
import {catalogAccess} from '@/lib/staff/access';
import {SiteHeader} from '@/components/discovery/site-header';
import {VisitEditor} from '@/components/staff/visit-editor';
import {VisitSummary} from '@/components/staff/visit-summary';
export const dynamic = 'force-dynamic';
export default async function Visits({params}: {params: Promise<{workOrderId: string}>}) {
  const {client, user, membership} = await catalogAccess(['admin','manager']); if (!user) redirect('/sign-in'); if (!membership) notFound();
  const {workOrderId} = await params; if (!/^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(workOrderId)) notFound();
  const order = await client.from('work_orders').select('id,title,status').eq('id', workOrderId).eq('organization_id', membership.organization_id).maybeSingle();
  if (order.error) throw new Error('Unable to load work order.'); if (!order.data) notFound();
  const offer = await client.from('contractor_work_offers').select('id,version').eq('work_order_id', workOrderId).eq('organization_id', membership.organization_id).eq('state','accepted').maybeSingle();
  if (offer.error) throw new Error('Unable to load assignment.');
  const current = offer.data ? await client.from('contractor_visits').select('id,state,version,starts_at,ends_at,shared_note').eq('offer_id', offer.data.id).eq('organization_id', membership.organization_id).in('state',['proposed','confirmed']).maybeSingle() : null;
  if (current?.error) throw new Error('Unable to load current appointment.');
  const returnTo = `/staff/work-orders/${workOrderId}/visits`;
  return <><SiteHeader/><main className="account-layout"><section className="account-card"><p className="eyebrow">Contractor visit scheduling</p><h1>{order.data.title}</h1>{!offer.data ? <p>A contractor must accept the work offer before a visit can be proposed.</p> : current?.data ? <><VisitSummary visit={current.data}/>{['assigned','scheduled'].includes(order.data.status) && <VisitEditor action="cancel" visitId={current.data.id} version={current.data.version} returnTo={returnTo}/>}</> : order.data.status === 'assigned' ? <VisitEditor action="propose" offerId={offer.data.id} offerVersion={offer.data.version} returnTo={returnTo}/> : <p>This work order is no longer ready for a new appointment. Resolve its current stage before rescheduling.</p>}<p><a href={`/staff/work-orders/${workOrderId}/visits/history`}>Appointment history ↗</a> · <a href={`/staff/work-orders/${workOrderId}/entry`}>Entry authorization ↗</a></p><a href={`/staff/work-orders/${workOrderId}`}>Back to work order</a></section></main></>;
}
