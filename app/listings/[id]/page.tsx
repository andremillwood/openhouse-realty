import { ViewingRequest } from '@/components/viewings/viewing-request';
import { EnquiryForm } from '@/components/enquiries/enquiry-form';
import { notFound } from 'next/navigation';
import { SiteHeader } from '@/components/discovery/site-header';
import { PropertyMap } from '@/components/discovery/property-map';
import { SaveProperty } from '@/components/auth/save-property';
import { createClient } from '@/lib/supabase/server';
import type { Home } from '@/lib/discovery/data';
export const dynamic = 'force-dynamic';
export default async function Property({ params }: { params: Promise<{ id: string }> }) {
  const { id } = await params;
  if (!/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(id)) notFound();
  const client = await createClient();
  const [{ data: row, error }, { data: { user } }] = await Promise.all([
    client.from('listings').select('id,title,area,intent,price_jmd,bedrooms,bathrooms,parking_spaces,size_sq_ft,description,photo_url,approximate_latitude,approximate_longitude,location_label').eq('id',id).eq('status','published').maybeSingle(),
    client.auth.getUser(),
  ]);
  if (error) throw new Error('Unable to load this property. Please try again.');
  if (!row) notFound();
  const { data: save } = user ? await client.from('saved_listings').select('listing_id').eq('user_id',user.id).eq('listing_id',id).maybeSingle() : { data:null };
  const {data:rawSlots,error:slotError}=await client.from('viewing_slots').select('id,starts_at,ends_at,state,hold_expires_at').eq('listing_id',row.id).gt('starts_at',new Date(Date.now()+30*60000).toISOString()).in('state',['open','held']).order('starts_at').limit(20);
  const slots=(rawSlots||[]).filter(slot=>slot.state==='open'||(slot.hold_expires_at&&Date.parse(slot.hold_expires_at)<=Date.now()));
  const mapHome: Home | null = row.approximate_latitude !== null && row.approximate_longitude !== null ? {id:row.id,title:row.title,area:row.area,intent:row.intent,price:Number(row.price_jmd),beds:row.bedrooms,baths:row.bathrooms,parking:row.parking_spaces,size:row.size_sq_ft||0,lat:row.approximate_latitude,lng:row.approximate_longitude,photo:'',description:row.description||''} : null;
  return <><SiteHeader/><main className="detail-page"><a className="back-link" href="/listings">← Back to properties</a><div className="detail-heading"><div><p className="eyebrow">{row.intent==='rent'?'FOR RENT':'FOR SALE'} · {row.area}</p><h1>{row.title}</h1><p>{row.location_label||row.area}, Jamaica</p></div><strong>JMD {Number(row.price_jmd).toLocaleString('en-JM')}{row.intent==='rent'?' / month':''}</strong></div>{row.photo_url&&<img className="detail-photo" src={row.photo_url} alt={row.title} referrerPolicy="no-referrer"/>}<div className="detail-columns"><div><div className="property-facts"><span><strong>{row.bedrooms}</strong>Bedrooms</span><span><strong>{row.bathrooms}</strong>Bathrooms</span>{row.size_sq_ft&&<span><strong>{row.size_sq_ft.toLocaleString()}</strong>Square feet</span>}<span><strong>{row.parking_spaces}</strong>Parking spaces</span></div><section><h2>Space for your next chapter.</h2><p>{row.description}</p></section><section><h2>Get to know the area.</h2>{mapHome?<><p>Explore the approved approximate neighborhood. The team confirms the exact address when arranging a visit.</p><PropertyMap homes={[mapHome]} demo={false}/><a className="button-link" href={`https://www.google.com/maps/search/?api=1&query=${mapHome.lat},${mapHome.lng}`} target="_blank" rel="noreferrer">Explore this approximate area ↗</a></>:<p>Ask the team for location details when arranging your visit.</p>}</section></div><aside className="contact-panel"><p className="eyebrow">MAKE YOUR NEXT MOVE</p><h2>Let’s find your fit.</h2><SaveProperty listingId={row.id} initialSaved={!!save}/><a className="button-link" href="/realtors#match">Match with a realtor ↗</a><p>The team confirms availability before a viewing.</p><section id="viewing">{slotError?<p>Viewing times are temporarily unavailable. You can still send an enquiry.</p>:<ViewingRequest slots={slots} listingId={row.id}/>}</section>{row.intent==="rent"&&<p><a className="button-link" href={`/apply/${row.id}`}>Apply for this rental ↗</a></p>}<section id="enquiry"><EnquiryForm listingId={row.id} initialMessage={`I would like to discuss ${row.title} and arrange a viewing.`}/></section></aside></div></main></>;
}
