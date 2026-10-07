import {redirect} from 'next/navigation';
import {createClient} from '@/lib/supabase/server';
import {SiteHeader} from '@/components/discovery/site-header';
export const dynamic='force-dynamic';
export const metadata={title:'Your enquiries | Open House Realty'};
export default async function Enquiries({searchParams}:{searchParams:Promise<Record<string,string|string[]|undefined>>}){
 const client=await createClient(),{data:{user},error}=await client.auth.getUser();
 if(error||!user?.email_confirmed_at)redirect('/sign-in');
 const input=await searchParams,page=typeof input.page==='string'&&/^\d{1,5}$/.test(input.page)?Math.max(1,Number(input.page)):1;
 const count=await client.from('enquiries').select('id',{head:true,count:'exact'}).eq('user_id',user.id);
 if(count.error||typeof count.count!=='number')throw new Error('Unable to count your enquiries.');
 const pages=Math.max(1,Math.ceil(count.count/25));if(page>pages)redirect(`/account/enquiries?page=${pages}`);
 const rows=await client.from('enquiries').select('id,status,message,created_at,listing_id,realtor_id').eq('user_id',user.id).order('created_at',{ascending:false}).order('id').range((page-1)*25,page*25-1);
 return <><SiteHeader/><main className="account-layout"><section className="account-card"><p className="eyebrow">Your conversations</p><h1>Your enquiries.</h1><p>Check stored submissions here before starting another enquiry after an interrupted connection. A stored enquiry does not confirm a viewing.</p>{rows.error?<p role="alert">Unable to load your enquiries. Please refresh.</p>:rows.data?.length?rows.data.map(row=><article key={row.id}><h2>{row.status==='new'?'Awaiting team follow-up':row.status==='contacted'?'The team is following up':row.status==='closed'?'Enquiry closed':'Status unavailable'}</h2><p>{row.listing_id?'Property enquiry':'Realtor introduction'} · Submitted {new Date(row.created_at).toLocaleString('en-JM',{timeZone:'America/Jamaica'})}</p><p className="enquiry-message">{row.message}</p><small>Reference: {row.id}</small></article>):<p>No stored enquiries for this account.</p>}<nav className="results-toolbar" aria-label="Your enquiry pages">{page>1?<a href={`/account/enquiries?page=${page-1}`}>← Previous</a>:<span/>}<span>{count.count} enquiries · Page {page} of {pages}</span>{page<pages?<a href={`/account/enquiries?page=${page+1}`}>Next →</a>:<span/>}</nav><p><a href="/account">Return to your account →</a></p></section></main></>;
}
