import {notFound,redirect} from 'next/navigation';
import {catalogAccess} from '@/lib/staff/access';
import {SiteHeader} from '@/components/discovery/site-header';
export const dynamic='force-dynamic';
export default async function WorkOrders({searchParams}:{searchParams:Promise<Record<string,string|string[]|undefined>>}){
 const {client,user,membership}=await catalogAccess(['admin','manager']);if(!user)redirect('/sign-in');if(!membership)notFound();const input=await searchParams;
 const states=['reported','triaged','assigned','scheduled','on_site','in_progress','completed','closed','cancelled'],state=typeof input.state==='string'&&states.includes(input.state)?input.state:'',page=typeof input.page==='string'&&/^\d{1,5}$/.test(input.page)?Math.max(1,Number(input.page)):1;
 const priorities=['urgent','high','standard','low'],priority=typeof input.priority==='string'&&priorities.includes(input.priority)?input.priority:'',search=typeof input.q==='string'&&input.q.trim().length<=100?input.q.trim():'';
 const href=(next:number)=>`/staff/work-orders?page=${next}${state?`&state=${state}`:''}${priority?`&priority=${priority}`:''}${search?`&q=${encodeURIComponent(search)}`:''}`;
 const query=(head=false)=>{let q=client.from('work_orders').select('id,title,priority,status,created_at',{head,count:'exact'}).eq('organization_id',membership.organization_id);if(state)q=q.eq('status',state);if(priority)q=q.eq('priority',priority);if(search)q=q.ilike('title',`%${search.replace(/[\\%_]/g,'\\$&')}%`);return q;};
 const count=await query(true);if(count.error||count.count===null)throw new Error('Unable to count work orders.');const pages=Math.max(1,Math.ceil(count.count/25));if(page>pages)redirect(href(pages));
 const rows=await query().order('created_at',{ascending:false}).order('id').range((page-1)*25,page*25-1);
 const now=Date.now();
 const visibleRows=rows.error?[]:rows.data||[];
 const summary=visibleRows.length?await client.rpc('work_order_service_target_summary',{p_work_order_ids:visibleRows.map(row=>row.id)}):{data:[],error:null};
 type Target={work_order_id:string;kind:string;version:number;action:string;due_at:string|null};
 const data=summary.data as Target[]|null;
 const valid=!summary.error&&Array.isArray(data)&&data.length<=50&&data.every(target=>visibleRows.some(row=>row.id===target.work_order_id)&&['response','resolution'].includes(target.kind)&&Number.isInteger(target.version)&&target.version>0&&['set','clear'].includes(target.action)&&(target.action==='clear'?target.due_at===null:typeof target.due_at==='string'&&Number.isFinite(Date.parse(target.due_at))))&&new Set(data.map(target=>`${target.work_order_id}:${target.kind}`)).size===data.length;
 const targetsByOrder=new Map(visibleRows.map(row=>[row.id,['response','resolution'].map(kind=>{
  if(!valid)return `${kind}: Unable to verify target`;
  const target=data!.find(target=>target.work_order_id===row.id&&target.kind===kind);
  if(!target)return `${kind}: Not set`;
  if(target.action==='clear')return `${kind}: Cleared`;
  const date=new Date(target.due_at!).toLocaleString('en-JM',{timeZone:'America/Jamaica'});
  const active=['reported','triaged','assigned','scheduled','on_site','in_progress'].includes(row.status);
  return `${kind}: ${date} · Jamaica time${active&&Date.parse(target.due_at!)<=now?' · Target time passed — review outcome':''}`;
 })]));
 return <><SiteHeader/><main className="account-layout"><section className="account-card"><p className="eyebrow">Property maintenance</p><h1>Your work orders.</h1><p>Report issues against a managed property, then record triage and priority decisions.</p><p><a href="/workspace">Team workspace ↗</a> · <a href="/staff/properties">Choose a property to report an issue ↗</a> · <a href="/staff/contractors">Approved contractor register ↗</a></p><form className="filter-bar" action="/staff/work-orders"><label>Find an issue<input name="q" defaultValue={search} maxLength={100} placeholder="Search issue titles"/></label><label>Priority<select name="priority" defaultValue={priority}><option value="">All priorities</option>{priorities.map(value=><option key={value} value={value}>{value}</option>)}</select></label><label>State<select name="state" defaultValue={state}><option value="">All states</option>{states.map(value=><option key={value} value={value}>{value.replaceAll('_',' ')}</option>)}</select></label><button className="secondary">Apply filters</button><a href="/staff/work-orders">Clear filters</a></form>{rows.error?<p role="alert">Unable to load work orders. Please refresh.</p>:rows.data?.length?rows.data.map(row=><article className="staff-editor" key={row.id}><h2><a href={`/staff/work-orders/${row.id}`}>{row.title}</a></h2><p>{row.status.replaceAll('_',' ')} · {row.priority} priority</p><ul aria-label="Current service targets">{targetsByOrder.get(row.id)?.map(target=><li key={target}>{target}</li>)}</ul><p><a href={`/staff/work-orders/${row.id}/targets`}>Review service targets ↗</a></p><small>{new Date(row.created_at).toLocaleString('en-JM',{timeZone:'America/Jamaica'})} · Jamaica time</small></article>):<p>No work orders in this view.</p>}<nav className="results-toolbar" aria-label="Work order pages">{page>1?<a href={href(page-1)}>← Previous</a>:<span/>}<span>{count.count||0} work orders · Page {page} of {pages}</span>{page<pages?<a href={href(page+1)}>Next →</a>:<span/>}</nav></section></main></>;
}
