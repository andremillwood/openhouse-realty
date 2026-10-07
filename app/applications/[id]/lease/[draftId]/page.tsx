import {redirect,notFound} from 'next/navigation';
import {SiteHeader} from '@/components/discovery/site-header';
import {createClient} from '@/lib/supabase/server';
import {uuidPattern} from '@/lib/enquiries/validation';
import {leaseReviewHistory} from '@/lib/leases/review';
import {leaseSummaryMoney} from '@/lib/leases/summary';
import {LeaseSummaryReview} from '@/components/leases/summary-review';
export const dynamic='force-dynamic';
export const metadata={title:'Lease summary review | Open House Realty'};
export default async function LeaseReview({params,searchParams}:{params:Promise<{id:string;draftId:string}>;searchParams:Promise<Record<string,string|string[]|undefined>>}){
 const {id,draftId}=await params;if(!uuidPattern.test(id)||!uuidPattern.test(draftId))notFound();
 const client=await createClient();const {data:{user},error:authError}=await client.auth.getUser();if(authError||!user?.email_confirmed_at)redirect('/sign-in');
 const raw=(await searchParams).page;const page=typeof raw==='string'&&/^\d{1,6}$/.test(raw)&&Number(raw)>=1&&Number(raw)<=100000?Number(raw):1;
 let result;try{result=await client.rpc('lease_summary_review_history',{p_application_id:id,p_draft_id:draftId,p_page:page});}catch{throw new Error('Unable to load the shared review history.');}
 if(result.error?.code==='42501')notFound();if(result.error)throw new Error('Unable to load the shared review history.');
 const history=leaseReviewHistory(result.data);if(history.summary.id!==draftId)throw new Error('Unable to confirm this summary.');
 const pages=Math.max(1,Math.ceil(history.total/25)),href=(n:number)=>`/applications/${id}/lease/${draftId}?page=${n}`;if(page>pages)redirect(href(pages));
 const summary=history.summary;
 return <><SiteHeader/><main className="account-layout"><section className="account-card"><p className="eyebrow">Shared lease summary discussion</p><h1>Review version {summary.version}.</h1><p><a href={history.role==='applicant'?`/applications/${id}/lease`:`/staff/leases/${id}`}>← Lease summaries</a></p><p>{summary.property_name} · {summary.unit_label}</p><dl><dt>Proposed dates</dt><dd>{summary.starts_on} through {summary.ends_on}</dd><dt>Monthly rent</dt><dd>{leaseSummaryMoney(summary.rent_minor)}</dd><dt>Proposed deposit</dt><dd>{leaseSummaryMoney(summary.deposit_minor)} · receipt not established</dd><dt>Proposed billing day</dt><dd>{summary.billing_day} · subject to the approved shorter-month schedule</dd><dt>Template</dt><dd>{summary.template_title}</dd></dl><p>A summary review is not legal acceptance or a signature. The full legal lease and authorized signing process are still required before resident activation.</p><LeaseSummaryReview key={`${history.release_id}-${history.revision}-${history.current}`} releaseId={history.release_id} revision={history.revision} role={history.role} latestAction={history.latest_action} current={history.current}/><h2>Shared review history</h2>{history.items.length?history.items.map(item=><article key={item.id}><h3>{item.action==='reviewed'?'Applicant recorded a review':item.action==='question'?'Applicant question':'Team reply'}</h3>{item.message&&<p className="enquiry-message">{item.message}</p>}<small>Response {item.version} · {new Date(item.created_at).toLocaleString('en-JM',{timeZone:'America/Jamaica'})}</small></article>):<p>No review responses recorded.</p>}{pages>1&&<nav aria-label="Shared review history pages">{page>1&&<a href={href(page-1)}>← Newer responses</a>}<span>Page {page} of {pages}</span>{page<pages&&<a href={href(page+1)}>Older responses →</a>}</nav>}</section></main></>;
}
