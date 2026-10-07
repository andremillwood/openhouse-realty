import {redirect,notFound} from 'next/navigation';
import {SiteHeader} from '@/components/discovery/site-header';
import {createClient} from '@/lib/supabase/server';
import {ApplicationForm} from '@/components/applications/application-form';
import {uuidPattern} from '@/lib/enquiries/validation';
export const dynamic='force-dynamic';
export default async function Apply({params}:{params:Promise<{listingId:string}>}){
 const {listingId}=await params;if(!uuidPattern.test(listingId))notFound();const client=await createClient();const {data:{user},error:authError}=await client.auth.getUser();if(authError||!user?.email_confirmed_at)redirect('/sign-in');
 const [{data:listing,error},{data:active,error:activeError},{data:enquiry,error:enquiryError}]=await Promise.all([
  client.from('listings').select('id,title,area,price_jmd').eq('id',listingId).eq('status','published').eq('intent','rent').maybeSingle(),
  client.from('rental_applications').select('id').eq('user_id',user.id).eq('listing_id',listingId).in('status',['submitted','under_review','needs_info','approved']).limit(1).maybeSingle(),
  client.from('enquiries').select('id').eq('user_id',user.id).eq('listing_id',listingId).order('created_at',{ascending:false}).limit(1).maybeSingle()
 ]);
 if(error||activeError||enquiryError)throw new Error('Unable to load application details.');if(active)redirect(`/applications/${active.id}`);if(!listing)notFound();
 return <><SiteHeader/><main className="account-layout"><section className="page-intro"><p className="eyebrow">RENTAL APPLICATION</p><h1>{listing.title}</h1><p>{listing.area} · Advertised rent JMD {Number(listing.price_jmd).toLocaleString('en-JM')} / month</p><a href={`/listings/${listing.id}`}>Back to the property ↗</a></section><ApplicationForm listingId={listing.id} enquiryId={enquiry?.id||null}/></main></>;
}
