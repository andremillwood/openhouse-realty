import {redirect} from 'next/navigation';
import {SiteHeader} from '@/components/discovery/site-header';
import {catalogAccess} from '@/lib/staff/access';
import {StaffCalendar} from '@/components/viewings/staff-calendar';
import {ViewingList} from '@/components/viewings/viewing-list';
export const dynamic='force-dynamic';
export default async function Viewings(){
 const {client,user,membership}=await catalogAccess(['admin','realtor','manager']);if(!user)redirect('/sign-in');
 if(!membership)return <><SiteHeader/><main className="account-layout"><section className="account-card"><h1>Staff access required.</h1><p>An administrator must assign viewing access to your organization.</p><a href="/account">Return to your account</a></section></main></>;
 const [{data:listings,error:listingError},{data:slots,error:slotError},{data:viewings,error:viewingError}]=await Promise.all([
 client.from('listings').select('id,title').eq('organization_id',membership.organization_id).order('title').limit(200),
 client.from('viewing_slots').select('id,listing_id,starts_at,ends_at,state,hold_expires_at').eq('organization_id',membership.organization_id).gte('starts_at',new Date(Date.now()-7*86400000).toISOString()).order('starts_at').limit(200),
 client.from('viewings').select('id,slot_id,listing_id,title_snapshot,requested_for,ends_at,hold_expires_at,contact_name,contact_email,phone,status,cancellation_reason').eq('organization_id',membership.organization_id).order('requested_for',{ascending:false}).limit(200),
 ]);
 return <><SiteHeader/><main className="listing-workspace"><section className="page-intro"><p className="eyebrow">STAFF VIEWINGS</p><h1>Make room for a new chapter.</h1><p>Manage availability, confirmations and viewing outcomes.</p><a href="/staff/enquiries">Enquiry inbox ↗</a></section>{listingError||slotError||viewingError?<p role="alert">Unable to load the viewing calendar. Please refresh.</p>:<><StaffCalendar listings={listings||[]} slots={slots||[]}/><section className="staff-viewings"><h2>Viewing requests and appointments</h2><ViewingList key={viewings?.map(viewing=>`${viewing.id}-${viewing.status}-${viewing.hold_expires_at}`).join('|')} viewings={viewings||[]} staff/></section></>}</main></>;
}
