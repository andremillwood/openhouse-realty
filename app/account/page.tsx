import {StaffNavigation} from '@/components/staff/staff-navigation';
import {applicationLabel} from '@/lib/applications/validation';
import { sellerStageLabel } from '@/lib/sellers/validation';
import { ViewingList } from '@/components/viewings/viewing-list';
import { redirect } from 'next/navigation';
import { createClient } from '@/lib/supabase/server';
import { SiteHeader } from '@/components/discovery/site-header';
import { SaveProperty } from '@/components/auth/save-property';
import { PasswordForm } from '@/components/auth/password-form';
export const dynamic = 'force-dynamic';
export default async function Account() {
  const client = await createClient();
  const { data: { user }, error } = await client.auth.getUser();
  if (error || !user?.email_confirmed_at) redirect('/sign-in');
  const [
    { data: saves, error: savedError },
    { data: enquiries, error: enquiryError },
    {data:viewings,error:viewingError},
    {data:sellerRequests,error:sellerError},
    {data:applications,error:applicationError},
    {data:cosigners,error:cosignerError}
  ] = await Promise.all([
    client.from('saved_listings').select('listing_id,listings(id,title,area,status)').eq('user_id', user.id),
    client.from('enquiries').select('id,status,message,created_at').eq('user_id',user.id).order('created_at',{ascending:false}).limit(50),
    client.from('viewings').select('id,slot_id,listing_id,title_snapshot,requested_for,ends_at,hold_expires_at,contact_name,contact_email,phone,status,cancellation_reason').eq('user_id',user.id).order('requested_for',{ascending:false}).limit(100),
    client.from('seller_leads').select('id,status,listing_id,listings(id,title,status),property_address,area,seller_lead_events(id,new_status,reason,created_at)').eq('user_id',user.id).order('created_at',{ascending:false}).limit(50),
    client.from('rental_applications').select('id,title_snapshot,status').eq('user_id',user.id).order('created_at',{ascending:false}).limit(50),
    client.from('application_cosigners').select('id,title_snapshot,state').or(`recipient_user_id.eq.${user.id},invite_email.eq.${JSON.stringify(user.email?.toLowerCase()||'')}`).order('created_at',{ascending:false}).limit(50)
  ]);
  return <><SiteHeader /><main className="account-layout"><section className="account-card"><p className="account-eyebrow">Verified account</p><h1>Your next chapter.</h1><p>Signed in as {user.email}</p><p>Your saved properties are available whenever you return.</p><a href="/inventory">Explore live properties ↗</a><h2>Saved properties</h2>{savedError ? <p>Unable to load saved properties. Please refresh.</p> : !saves?.length ? <p>You haven’t saved any published properties yet.</p> : saves.map(save => { const listing = Array.isArray(save.listings) ? save.listings[0] : save.listings; return <article key={save.listing_id}><h3>{listing?.title || 'Property no longer available'}</h3>{listing && <p>{listing.area}</p>}<SaveProperty listingId={save.listing_id} initialSaved /></article>; })}<p><a href="/account/open-houses">Your open-house RSVPs ↗</a></p><h2>Your viewings</h2>{viewingError?<p>Unable to load viewings. Please refresh.</p>:<ViewingList key={viewings?.map(viewing=>`${viewing.id}-${viewing.status}-${viewing.hold_expires_at}`).join('|')} viewings={viewings||[]}/>}<h2>Your rental applications</h2>{applicationError?<p>Unable to load applications. Please refresh.</p>:!applications?.length?<p>Your submitted rental applications will appear here.</p>:applications.map(application=><article key={application.id}><h3>{application.title_snapshot}</h3><p>{applicationLabel(application.status)}</p><a href={`/applications/${application.id}`}>Open your application ↗</a></article>)}{cosignerError?<p>Unable to load co-signer invitations.</p>:!!cosigners?.length&&<section><h2>Your co-signer invitations</h2>{cosigners.map(invitation=><article key={invitation.id}><h3>{invitation.title_snapshot}</h3><p>{invitation.state}</p><a href={`/cosigners/${invitation.id}`}>Review invitation ↗</a></article>)}</section>}<h2>Your property reviews</h2>{sellerError?<p>Unable to load property reviews. Please refresh.</p>:!sellerRequests?.length?<p><a href="/sell">Start a private property review ↗</a></p>:sellerRequests.map(lead=><article key={lead.id}><h3>{sellerStageLabel(lead.status)}</h3><p>{lead.property_address} · {lead.area}</p><small>Reference: {lead.id}</small>{lead.listing_id&&<p>Listing preparation is linked to this review. {(()=>{const listing=Array.isArray(lead.listings)?lead.listings[0]:lead.listings;return listing?.status==="published"?<a href={`/listings/${listing.id}`}>View your published listing ↗</a>:"The listing is awaiting publication or is currently unavailable.";})()}</p>}{lead.seller_lead_events?.slice().sort((a,b)=>b.created_at.localeCompare(a.created_at)).map(event=><p key={event.id}>{sellerStageLabel(event.new_status)}{event.reason&&`: ${event.reason}`}</p>)}</article>)}<h2>Your enquiries</h2><p><a href="/account/enquiries">View your full enquiry history ↗</a></p>{enquiryError ? <p>Unable to load enquiries. Please refresh.</p> : !enquiries?.length ? <p>Your submitted enquiries will appear here.</p> : enquiries.map(enquiry=><article key={enquiry.id}><h3>{enquiry.status === "new" ? "Awaiting team follow-up" : enquiry.status === "contacted" ? "The team is following up" : "Enquiry closed"}</h3><p className="enquiry-message">{enquiry.message}</p><small>Reference: {enquiry.id}</small></article>)}<p><a href="/account/portfolio">Your approved owner portfolio →</a></p><p><a href="/account/invitations">Your team invitations →</a></p><StaffNavigation/><p><a href="/account/work-offers">Your contractor work offers ↗</a></p><h2>Your realtor preferences</h2><p><a href="/realtors#match">Review, change or delete your saved working preferences ↗</a></p><h2>Account security</h2><PasswordForm /><form action="/auth/signout" method="post"><button>Sign out</button></form></section></main></>;
}
