import {redirect} from 'next/navigation';
import {catalogAccess} from '@/lib/staff/access';
import {SiteHeader} from '@/components/discovery/site-header';
import {comparisonPeriod,countDelta} from '@/lib/reports/comparison';
import {reportCount} from '@/lib/reports/count';
export const dynamic='force-dynamic';
export const metadata={title:'Compare demand periods | Open House Realty'};
const metrics=[
 ...['new','contacted','closed'].map(state=>({table:'enquiries',state,label:`Enquiries: ${state}`,event:false})),
 ...['requested','confirmed','completed','cancelled','no_show','expired'].map(state=>({table:'viewings',state,label:`Viewings: ${state.replace('_',' ')}`,event:false})),
 ...['confirm','complete','cancel','no_show'].map(state=>({table:'viewing_events',state,label:`Recorded events: ${state.replace('_',' ')}`,event:true}))
];
export default async function CompareDemand({searchParams}:{searchParams:Promise<Record<string,string|string[]|undefined>>}){
 const {client,user,membership}=await catalogAccess(['admin','realtor','manager']);
 if(!user)redirect('/sign-in');if(!membership)redirect('/account');
 let period:ReturnType<typeof comparisonPeriod>|null=null,error='';
 const input=await searchParams;
 try{period=comparisonPeriod(input);}catch(reason){error=reason instanceof Error?reason.message:'Check the report dates.';}
 const results=period?await Promise.all(metrics.map(async metric=>{
  const counts=await Promise.all([period.current,period.previous].map(async range=>{
   let query=client.from(metric.table).select(metric.event?'id,viewings!inner(organization_id)':'id',{head:true,count:'exact'})
    .eq(metric.event?'viewings.organization_id':'organization_id',membership.organization_id)
    .eq(metric.event?'event_name':'status',metric.state).gte('created_at',range.from).lt('created_at',range.until);
   return reportCount(query);
  }));
  return {metric,current:counts[0],previous:counts[1]};
 })):[];
 const show=(value:number|null)=>value===null?'Unavailable':value.toLocaleString('en-JM');
 return <><SiteHeader/><main className="account-layout"><section className="account-card"><p className="eyebrow">Organization report</p><h1>Compare demand periods.</h1><p>Compare your selected Jamaica calendar dates with the immediately preceding, nonoverlapping period of equal length.</p><form method="get" className="staff-fields"><label>From (Jamaica)<input type="date" name="start" required defaultValue={typeof input.start==='string'?input.start:''}/></label><label>Through (Jamaica)<input type="date" name="end" required defaultValue={typeof input.end==='string'?input.end:''}/></label><button>Compare periods</button></form>{error&&<p role="alert">{error}</p>}{period&&<><p>Selected: {period.current.start} through {period.current.end}. Previous: {period.previous.start} through {period.previous.end}. Each period includes {period.days} calendar days.</p><p>Enquiry and viewing rows show current stored states of records submitted in each period. They do not measure transitions during that period. Event rows count audit events recorded in each period, not unique prospects, visits, conversion rates or sales. Staff-recorded completion does not independently verify attendance. Expired holds can remain requested until resolved.</p><p>Change is the selected count minus the previous count. No percentage is calculated, including when the previous count is zero. Counts are read independently and can change while the report loads.</p><table><caption>Equal-length demand comparison</caption><thead><tr><th scope="col">Metric</th><th scope="col">Selected</th><th scope="col">Previous</th><th scope="col">Change in records</th></tr></thead><tbody>{results.map(row=><tr key={row.metric.table+row.metric.state}><th scope="row">{row.metric.label}</th><td>{show(row.current)}</td><td>{show(row.previous)}</td><td>{countDelta(row.current,row.previous)}</td></tr>)}</tbody></table>{results.some(row=>row.current===null||row.previous===null)&&<p role="alert">Some counts could not be loaded. Their changes are unavailable. Refresh before using this report for a decision.</p>}</>}<p><a href="/staff/reports/demand">Return to demand workload →</a></p></section></main></>;
}
