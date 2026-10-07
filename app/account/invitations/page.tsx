import {redirect} from 'next/navigation';
import {createClient} from '@/lib/supabase/server';
import {SiteHeader} from '@/components/discovery/site-header';
export const dynamic='force-dynamic';
export default async function Invitations({searchParams}:{searchParams:Promise<Record<string,string|string[]|undefined>>}){
 const client=await createClient(),{data:{user},error}=await client.auth.getUser();if(error||!user?.email_confirmed_at||!user.email)redirect('/sign-in');
 const input=await searchParams,page=typeof input.page==='string'&&/^\d{1,5}$/.test(input.page)?Math.max(1,Number(input.page)):1;
 const count=await client.from('staff_invitations').select('id',{head:true,count:'exact'}).eq('invite_email',user.email.toLowerCase());if(count.error)throw new Error('Unable to count your invitations.');
 const pages=Math.max(1,Math.ceil((count.count||0)/25));if(page>pages)redirect(`/account/invitations?page=${pages}`);
 const rows=await client.from('staff_invitations').select('id,role,state,expires_at,created_at').eq('invite_email',user.email.toLowerCase()).order('created_at',{ascending:false}).order('id').range((page-1)*25,page*25-1);
 return <><SiteHeader/><main className="account-layout"><section className="account-card"><p className="eyebrow">Verified account</p><h1>Your team invitations.</h1><p>Review the organization and approved role before accepting access for {user.email}.</p>{rows.error?<p role="alert">Unable to load invitations. Please refresh.</p>:rows.data?.length?rows.data.map(row=><article key={row.id}><h2>{row.role} invitation</h2><p>{row.state} · Expires {new Date(row.expires_at).toLocaleDateString('en-JM',{timeZone:'America/Jamaica'})}</p><a href={`/account/invitations/${row.id}`}>Review organization and invitation →</a></article>):<p>No staff invitations for your verified email.</p>}<nav className="results-toolbar" aria-label="Your invitation pages">{page>1?<a href={`/account/invitations?page=${page-1}`}>← Previous</a>:<span/>}<span>{count.count||0} invitations · Page {page} of {pages}</span>{page<pages?<a href={`/account/invitations?page=${page+1}`}>Next →</a>:<span/>}</nav><a href="/account">Return to your account →</a></section></main></>;
}
