import {notFound,redirect} from 'next/navigation';
import {SiteHeader} from '@/components/discovery/site-header';
import {ServiceTargetForm} from '@/components/staff/service-target-form';
import {catalogAccess} from '@/lib/staff/access';
import {uuidPattern} from '@/lib/enquiries/validation';
import {serviceTargetKinds} from '@/lib/staff/service-targets';
export const dynamic='force-dynamic';
const date=(value:string)=>new Date(value).toLocaleString('en-JM',{timeZone:'America/Jamaica'});
export default async function ServiceTargets({params,searchParams}:{params:Promise<{workOrderId:string}>;searchParams:Promise<Record<string,string|string[]|undefined>>}){
 const {workOrderId}=await params;if(!uuidPattern.test(workOrderId))notFound();
 const {client,user,membership}=await catalogAccess(['admin','manager']);if(!user)redirect('/sign-in');if(!membership)notFound();
 const org=membership.organization_id;
 const order=await client.from('work_orders').select('id,title,revision,status').eq('id',workOrderId).eq('organization_id',org).maybeSingle();
 if(order.error)throw Error('Unable to verify work order.');if(!order.data)notFound();const record=order.data;
 const query=()=>client.from('work_order_service_target_events').select('id,kind,version,work_order_version,action,due_at,reason,actor_user_id,created_at').eq('work_order_id',workOrderId).eq('organization_id',org);
 const [count,...latest]=await Promise.all([client.from('work_order_service_target_events').select('id',{head:true,count:'exact'}).eq('work_order_id',workOrderId).eq('organization_id',org),...serviceTargetKinds.map(kind=>query().eq('kind',kind).order('version',{ascending:false}).limit(1).maybeSingle())]);
 if(count.error||count.count===null||latest.some((item,index)=>item.error||item.data&&(!Number.isInteger(item.data.version)||item.data.version<1||item.data.kind!==serviceTargetKinds[index]||!['set','clear'].includes(item.data.action)||(item.data.action==='set'&&!Number.isFinite(Date.parse(item.data.due_at)))||(item.data.action==='clear'&&item.data.due_at!==null))))throw Error('Unable to verify current targets.');
 const input=await searchParams,raw=input.page,page=typeof raw==='string'&&/^\d{1,5}$/.test(raw)?Math.max(1,Number(raw)):1;
 const pages=Math.max(1,Math.ceil(count.count/25)),href=(p:number)=>`/staff/work-orders/${workOrderId}/targets?page=${p}`;
 if(page>pages)redirect(href(pages));
 const history=await query().order('created_at',{ascending:false}).order('id',{ascending:false}).range((page-1)*25,page*25-1);
 const editable=Number.isInteger(record.revision)&&record.revision>0&&['reported','triaged','assigned','scheduled','on_site','in_progress'].includes(record.status);
 return <><SiteHeader/><main className="account-layout"><section className="account-card"><p className="eyebrow">Service targets · Work order revision {record.revision}</p><h1>{record.title}</h1><p>Staff planning dates for response and resolution. Completion is recorded separately.</p>{!editable&&<p role="alert">This work order is closed or unavailable for target changes. History remains available.</p>}<h2>Current targets</h2>{serviceTargetKinds.map((kind,index)=>{const target=latest[index].data;return <article key={kind}><h3>{kind} target</h3><p>{target?.action==='set'?`${date(target.due_at)} · Jamaica time`:target?'Cleared':'Not set'}</p>{target?.action==='set'&&Date.parse(target.due_at)<Date.now()&&editable&&<p>Target time has passed. Review the work record to confirm the outcome.</p>}{target&&<p>Target revision {target.version} · {target.reason}</p>}{editable&&!history.error&&<ServiceTargetForm key={`${kind}-${target?.version||0}`} workOrderId={workOrderId} workOrderVersion={record.revision} kind={kind} version={target?.version||0}/>}</article>;})}<h2>Target history</h2>{history.error?<p role="alert">Unable to verify target history. Refresh before recording a decision.</p>:history.data?.length?history.data.map(target=><article key={target.id}><h3>{target.kind} · Revision {target.version} · {target.action==='set'?'Target set':'Target cleared'}</h3>{target.due_at&&<p>{date(target.due_at)} · Jamaica time</p>}<p>{target.reason}</p><small>Actor: {target.actor_user_id} · Work order revision {target.work_order_version} · {date(target.created_at)} · Jamaica time</small></article>):<p>No target decisions recorded.</p>}<nav className="results-toolbar" aria-label="Target history pages">{page>1&&<a href={href(page-1)}>← Newer</a>}<span>Page {page} of {pages} · {count.count} decisions</span>{page<pages&&<a href={href(page+1)}>Older →</a>}</nav><a href={`/staff/work-orders/${workOrderId}`}>← Work order</a></section></main></>;
}
