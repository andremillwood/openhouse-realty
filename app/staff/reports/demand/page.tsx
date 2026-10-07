import {reportCount} from '@/lib/reports/count';
import {reportPeriod} from '@/lib/reports/period';
import {redirect} from 'next/navigation';
import {catalogAccess} from '@/lib/staff/access';
import {SiteHeader} from '@/components/discovery/site-header';
export const dynamic='force-dynamic';
export const metadata={title:'Demand workload | Open House Realty'};
const groups=[
 {table:'enquiries',title:'Enquiry workload',href:'/staff/enquiries',states:[['new','Awaiting follow-up'],['contacted','Following up'],['closed','Closed']]},
 {table:'viewings',title:'Viewing workload',href:'/staff/viewings',states:[['requested','Requested'],['confirmed','Confirmed'],['completed','Completed'],['cancelled','Cancelled'],['no_show','No-show'],['expired','Expired']]}
];
export default async function DemandReport({searchParams}:{searchParams:Promise<Record<string,string|string[]|undefined>>}){
 const {client,user,membership}=await catalogAccess(['admin','realtor','manager']);
 if(!user)redirect('/sign-in');if(!membership)redirect('/account');
 let period:ReturnType<typeof reportPeriod>=null;let periodError='';try{period=reportPeriod(await searchParams);}catch(error){periodError=error instanceof Error?error.message:'Check the report dates.';}
 const activityPromise=periodError?Promise.resolve([]):Promise.all([['confirm','Confirmation events'],['complete','Completion events'],['cancel','Cancellation events'],['no_show','No-show events']].map(async([event,label])=>{
  let query=client.from('viewing_events').select('id,viewings!inner(organization_id)',{head:true,count:'exact'}).eq('viewings.organization_id',membership.organization_id).eq('event_name',event);
  if(period)query=query.gte('created_at',period.from).lt('created_at',period.until);
  return {event,label,count:await reportCount(query)};
 }));
 const results=periodError?[]:await Promise.all(groups.map(async group=>({group,counts:await Promise.all(group.states.map(async([status,label])=>{
  let query=client.from(group.table).select('id',{head:true,count:'exact'}).eq('organization_id',membership.organization_id).eq('status',status);
  if(period)query=query.gte('created_at',period.from).lt('created_at',period.until);
  return {status,label,count:await reportCount(query)};
 }))})));
 const activity=await activityPromise;
 return <><SiteHeader/><main className="account-layout"><section className="account-card"><p className="eyebrow">Organization report</p><h1>Demand workload.</h1><p><a href={period?`/staff/reports/demand/compare?start=${period.start}&end=${period.end}`:"/staff/reports/demand/compare"}>Compare equal-length periods →</a></p><p>Current stored enquiry and viewing states for your organization. {period?`Counts include records submitted from ${period.start} through ${period.end}, by Jamaica calendar dates.`:'Counts include all dates.'} Counts are read independently when this page loads. This shows the current state of records submitted in the period, not transitions or outcomes that occurred during it.</p><p>A request is not a confirmed viewing. Expired holds may still have a stored requested state until the scheduling workflow resolves them. These counts describe workload, not conversion rates or completed sales.</p><form method="get" className="staff-fields"><label>Submitted from (Jamaica)<input type="date" name="start" defaultValue={period?.start}/></label><label>Submitted through (Jamaica)<input type="date" name="end" defaultValue={period?.end}/></label><button>Apply period</button><a href="/staff/reports/demand">All dates</a></form>{periodError&&<p role="alert">{periodError}</p>}{results.map(({group,counts})=><section key={group.table}><h2>{group.title}</h2><table><caption>Stored records by current state</caption><thead><tr><th scope="col">State</th><th scope="col">Records</th></tr></thead><tbody>{counts.map(item=><tr key={item.status}><th scope="row">{item.label}</th><td>{item.count===null?'Unavailable':item.count.toLocaleString('en-JM')}</td></tr>)}</tbody></table>{counts.some(item=>item.count===null)&&<p role="alert">Some counts could not be loaded. Refresh before using this report for a decision.</p>}<p><a href={group.href}>Open {group.title.toLowerCase()} →</a></p></section>)}<section><h2>Recorded viewing activity</h2><p>Audit events recorded {period?`from ${period.start} through ${period.end} (Jamaica)`:"across all dates"}. These are event counts, not unique prospects, visits or sales; staff-recorded completion does not independently verify attendance.</p>{!periodError&&<table><caption>Recorded transitions during the event period</caption><thead><tr><th scope="col">Event</th><th scope="col">Records</th></tr></thead><tbody>{activity.map(item=><tr key={item.event}><th scope="row">{item.label}</th><td>{item.count===null?"Unavailable":item.count.toLocaleString("en-JM")}</td></tr>)}</tbody></table>}{activity.some(item=>item.count===null)&&<p role="alert">Some activity counts could not be loaded. Refresh before using them.</p>}</section><p><a href="/account">Return to your account →</a></p></section></main></>;
}
