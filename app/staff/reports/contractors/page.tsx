import {reportCount} from '@/lib/reports/count';
import {redirect} from 'next/navigation';
import {catalogAccess} from '@/lib/staff/access';
import {SiteHeader} from '@/components/discovery/site-header';
import {reportPeriod} from '@/lib/reports/period';
export const dynamic='force-dynamic';
export const metadata={title:'Contractor coordination | Open House Realty'};
const groups=[
 {table:'contractor_work_offers',title:'Work offers',states:[['offered','Offered'],['accepted','Accepted'],['declined','Declined'],['withdrawn','Withdrawn'],['expired','Resolved as expired']]},
 {table:'contractor_visits',title:'Contractor visits',states:[['proposed','Proposed'],['confirmed','Confirmed'],['declined','Declined'],['cancelled','Cancelled']]}
];
export default async function ContractorReport({searchParams}:{searchParams:Promise<Record<string,string|string[]|undefined>>}){
 const {client,user,membership}=await catalogAccess(['admin','manager']);if(!user)redirect('/sign-in');if(!membership)redirect('/account');
 let period:ReturnType<typeof reportPeriod>=null;let error='';try{period=reportPeriod(await searchParams);}catch(cause){error=cause instanceof Error?cause.message:'Check the report dates.';}
 const metrics=groups.flatMap(group=>group.states.map(([state,label])=>({table:group.table,title:group.title,state,label,key:group.table+state})));
 const counts=error?[]:await Promise.all(metrics.map(async metric=>{
  let query=client.from(metric.table).select('id',{head:true,count:'exact'}).eq('organization_id',membership.organization_id).eq('state',metric.state);
  if(period)query=query.gte('created_at',period.from).lt('created_at',period.until);
  return {...metric,count:await reportCount(query)};
 }));
 return <><SiteHeader/><main className="account-layout"><section className="account-card"><p className="eyebrow">Management report</p><h1>Contractor coordination.</h1><p>Current stored offer and visit states for your organization, {period?`created from ${period.start} through ${period.end} (Jamaica)`:'across all creation dates'}. The period uses record creation, not appointment time or response time. Counts are read independently.</p><form method="get" className="staff-fields"><label>Created from (Jamaica)<input type="date" name="start" defaultValue={period?.start}/></label><label>Created through (Jamaica)<input type="date" name="end" defaultValue={period?.end}/></label><button>Apply period</button><a href="/staff/reports/contractors">All dates</a></form>{error?<p role="alert">{error}</p>:groups.map(group=><section key={group.table}><h2>{group.title}</h2><table><caption>Current stored states of created records</caption><thead><tr><th scope="col">State</th><th scope="col">Records</th></tr></thead><tbody>{counts.filter(item=>item.table===group.table).map(item=><tr key={item.key}><th scope="row">{item.label}</th><td>{item.count===null?'Unavailable':item.count.toLocaleString('en-JM')}</td></tr>)}</tbody></table></section>)}{counts.some(item=>item.count===null)&&<p role="alert">Some counts are unavailable. Refresh before making a decision.</p>}<p>Offered records may have passed their response window before the workflow resolves them as expired. Accepted offers can remain in history after the work ends. A confirmed visit does not establish entry authorization, attendance or completion.</p><p>These are record counts, not unique contractors or performance ratings. Open a work order to review the current assignment, visit and entry details.</p><p><a href="/staff/work-orders">Open the work-order queue →</a> · <a href="/staff/contractors">Approved contractor register →</a></p><p><a href="/account">Return to your account →</a></p></section></main></>;
}
