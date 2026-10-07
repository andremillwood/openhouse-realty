import {notFound,redirect} from 'next/navigation';
import {catalogAccess} from '@/lib/staff/access';
import {SiteHeader} from '@/components/discovery/site-header';
import {ArrivalEditor} from '@/components/open-houses/arrival-editor';
export const dynamic='force-dynamic';
export default async function ArrivalPage({params}:{params:Promise<{eventId:string}>}){
 const {client,user,membership}=await catalogAccess(['admin','realtor','manager']);if(!user)redirect('/sign-in');if(!membership)notFound();const {eventId}=await params;if(!/^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(eventId))notFound();const event=await client.from('open_house_events').select('id,title,status,ends_at,open_house_management!inner(organization_id)').eq('id',eventId).eq('open_house_management.organization_id',membership.organization_id).maybeSingle();if(event.error)throw new Error('Unable to verify event access.');if(!event.data)notFound();const arrival=await client.from('open_house_arrival').select('event_id,meeting_point,details,latitude,longitude,is_active,version').eq('event_id',eventId).eq('organization_id',membership.organization_id).maybeSingle();if(arrival.error)throw new Error('Unable to load arrival instructions.');
 return <><SiteHeader/><main className="account-layout"><section className="account-card"><p className="eyebrow">Private approved arrival details</p><h1>{event.data.title}</h1><ArrivalEditor key={arrival.data?.version||0} eventId={eventId} arrival={arrival.data} canSave={event.data.status==='scheduled'&&Date.parse(event.data.ends_at)>Date.now()}/><p><a href={`/staff/open-houses/${eventId}/arrival/history`}>Review arrival change history ↗</a></p><a href={`/staff/open-houses/${eventId}`}>Back to attendee roster ↗</a></section></main></>;
}
