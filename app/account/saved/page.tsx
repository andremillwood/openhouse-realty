import {redirect} from 'next/navigation';
import {createClient} from '@/lib/supabase/server';
import {SiteHeader} from '@/components/discovery/site-header';
import {SaveProperty} from '@/components/auth/save-property';
export const dynamic='force-dynamic';
export const metadata={title:'Saved properties | Open House Realty'};
export default async function SavedProperties({searchParams}:{searchParams:Promise<Record<string,string|string[]|undefined>>}){
 const client=await createClient();
 const {data:{user},error}=await client.auth.getUser();
 if(error||!user?.email_confirmed_at||user.is_anonymous)redirect('/sign-in');
 const input=await searchParams;
 const page=typeof input.page==='string'&&/^\d{1,5}$/.test(input.page)?Math.max(1,Number(input.page)):1;
 const count=await client.from('saved_listings').select('listing_id',{head:true,count:'exact'}).eq('user_id',user.id);
 if(count.error||!Number.isInteger(count.count)||count.count===null||count.count<0)throw Error('Unable to count saved properties.');
 const pages=Math.max(1,Math.ceil(count.count/25));
 if(page>pages)redirect(`/account/saved?page=${pages}`);
 const rows=await client.from('saved_listings').select('listing_id,created_at,listings(id,title,area,status)').eq('user_id',user.id).order('created_at',{ascending:false}).order('listing_id').range((page-1)*25,page*25-1);
 return <><SiteHeader/><main className="account-layout"><section className="account-card"><p className="eyebrow">Your property shortlist</p><h1>Saved for your next move.</h1><p>Return to the homes that caught your eye. Availability may change after you save a property.</p>{rows.error?<p role="alert">Unable to load saved properties. Refresh before making a decision.</p>:rows.data?.length?rows.data.map(save=>{
  const listing=Array.isArray(save.listings)?save.listings[0]:save.listings;
  const available=listing?.id===save.listing_id&&listing.status==='published';
  return <article className="staff-editor" key={save.listing_id}><h2>{available?<a href={`/listings/${listing.id}`}>{listing.title}</a>:'Property currently unavailable'}</h2>{available?<p>{listing.area}</p>:<p>This saved reference remains yours, but public property details are unavailable.</p>}<SaveProperty listingId={save.listing_id} initialSaved refreshAfterChange/></article>;
 }):<p>No saved properties on this page. <a href="/listings">Explore available properties →</a></p>}<nav className="results-toolbar" aria-label="Saved property pages">{page>1?<a href={`/account/saved?page=${page-1}`}>← Previous</a>:<span/>}<span>{count.count} saved references · Page {page} of {pages}</span>{page<pages?<a href={`/account/saved?page=${page+1}`}>Next →</a>:<span/>}</nav><p><a href="/account">Return to your account →</a> · <a href="/realtors#match">Find your realtor →</a></p></section></main></>;
}
