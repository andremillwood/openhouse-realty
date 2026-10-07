import {reportCount} from '@/lib/reports/count';
import {redirect} from 'next/navigation';
import {catalogAccess} from '@/lib/staff/access';
import {SiteHeader} from '@/components/discovery/site-header';
import {reportPeriod} from '@/lib/reports/period';
export const dynamic='force-dynamic';
export const metadata={title:'Maintenance workload | Open House Realty'};
const states=['reported','triaged','assigned','scheduled','on_site','in_progress','completed','closed','cancelled'];
const openStates=states.slice(0,6);
export default async function MaintenanceReport({searchParams}:{searchParams:Promise<Record<string,string|string[]|undefined>>}){
 const {client,user,membership}=await catalogAccess(['admin','manager']);if(!user)redirect('/sign-in');if(!membership)redirect('/account');
 let period:ReturnType<typeof reportPeriod>=null;let error='';try{period=reportPeriod(await searchParams);}catch(cause){error=cause instanceof Error?cause.message:'Check the report period.';}
 const metrics=[...states.map(status=>({key:status,label:status.replaceAll('_',' '),status,priority:''})),...['urgent','high','standard','low'].map(priority=>({key:'priority-'+priority,label:priority,status:'',priority}))];
 const counts=error?[]:await Promise.all(metrics.map(async metric=>{
  let query=client.from('work_orders').select('id',{head:true,count:'exact'}).eq('organization_id',membership.organization_id);
  query=metric.status?query.eq('status',metric.status):query.eq('priority',metric.priority).in('status',openStates);
  if(period)query=query.gte('created_at',period.from).lt('created_at',period.until);
  return {...metric,count:await reportCount(query)};
 }));
 return <><SiteHeader/><main className="account-layout"><section className="account-card"><p className="eyebrow">Management report</p><h1>Maintenance workload.</h1><p>Current work-order states for your organization, {period?`reported from ${period.start} through ${period.end} (Jamaica)`:'across all report dates'}. Counts are read independently and describe the current state of the reported cohort, not activity completed during the period.</p><form method="get" className="staff-fields"><label>Reported from (Jamaica)<input type="date" name="start" defaultValue={period?.start}/></label><label>Reported through (Jamaica)<input type="date" name="end" defaultValue={period?.end}/></label><button>Apply period</button><a href="/staff/reports/maintenance">All dates</a></form>{error?<p role="alert">{error}</p>:<><h2>Work orders by state</h2><table><caption>Current stored states</caption><thead><tr><th scope="col">State</th><th scope="col">Records</th></tr></thead><tbody>{counts.filter(item=>item.status).map(item=><tr key={item.key}><th scope="row"><a href={`/staff/work-orders?state=${item.status}`}>{item.label}</a></th><td>{item.count===null?'Unavailable':item.count.toLocaleString('en-JM')}</td></tr>)}</tbody></table><h2>Open work by priority</h2><p>Open includes reported, triaged, assigned, scheduled, on-site and in-progress work. Completed, closed and cancelled records are excluded. Priority is the recorded triage decision; it does not establish a contractual response deadline.</p><table><caption>Recorded priority of open work</caption><thead><tr><th scope="col">Priority</th><th scope="col">Open records</th></tr></thead><tbody>{counts.filter(item=>item.priority).map(item=><tr key={item.key}><th scope="row">{item.label}</th><td>{item.count===null?'Unavailable':item.count.toLocaleString('en-JM')}</td></tr>)}</tbody></table>{counts.some(item=>item.count===null)&&<p role="alert">Some counts are unavailable. Refresh before making a decision.</p>}<p>Queue links show all dates for the selected state; the report period is not applied to those queues.</p></>}<p><a href="/staff/work-orders">Open the work-order queue →</a></p><p><a href="/account">Return to your account →</a></p></section></main></>;
}
