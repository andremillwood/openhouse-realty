import {notFound,redirect} from 'next/navigation';
import {catalogAccess} from '@/lib/staff/access';
import {SiteHeader} from '@/components/discovery/site-header';
export const dynamic='force-dynamic';
export default async function History({searchParams}:{searchParams:Promise<Record<string,string|string[]|undefined>>}){
 const {client,user,membership}=await catalogAccess(['admin']);if(!user)redirect('/sign-in');if(!membership)notFound();
 const input=await searchParams,page=typeof input.page==='string'&&/^\d{1,5}$/.test(input.page)?Math.max(1,Number(input.page)):1;
 const query=(head=false)=>client.from('staff_invitation_events').select('id,invitation_id,actor_user_id,action,previous_state,new_state,version,reason,created_at',{head,count:'exact'}).eq('organization_id',membership.organization_id);
 const count=await query(true);if(count.error)throw new Error('Unable to count invitation changes.');const pages=Math.max(1,Math.ceil((count.count||0)/25));if(page>pages)redirect(`/staff/invitations/history?page=${pages}`);
 const rows=await query().order('created_at',{ascending:false}).order('id').range((page-1)*25,page*25-1);
 return <><SiteHeader/><main className="account-layout"><section className="account-card"><p className="eyebrow">Private administrator audit</p><h1>Invitation decisions.</h1><p>Approval and recipient decision reasons remain available to organization administrators.</p>{rows.error?<p role="alert">Unable to load invitation changes. Please refresh.</p>:rows.data?.length?rows.data.map(row=><article className="staff-editor" key={row.id}><h2>{row.action} · Revision {row.version}</h2><p>{row.previous_state||'New invitation'} → {row.new_state}</p><p>{new Date(row.created_at).toLocaleString('en-JM',{timeZone:'America/Jamaica'})} · Jamaica time</p><p className="enquiry-message">{row.reason}</p><small>Invitation: {row.invitation_id}<br/>Actor: {row.actor_user_id}</small></article>):<p>No invitation decisions yet.</p>}<nav className="results-toolbar" aria-label="Invitation history pages">{page>1?<a href={`/staff/invitations/history?page=${page-1}`}>← Previous</a>:<span/>}<span>{count.count||0} changes · Page {page} of {pages}</span>{page<pages?<a href={`/staff/invitations/history?page=${page+1}`}>Next →</a>:<span/>}</nav><a href="/staff/invitations">Return to invitations →</a></section></main></>;
}
