import {notFound,redirect} from 'next/navigation';
import {catalogAccess} from '@/lib/staff/access';
import {SiteHeader} from '@/components/discovery/site-header';
import {PreventivePlanEditor} from '@/components/staff/preventive-plan-editor';
export const dynamic='force-dynamic';
export default async function NewPreventivePlan({searchParams}:{searchParams:Promise<Record<string,string|string[]|undefined>>}){
 const {client,user,membership}=await catalogAccess(['admin','manager']);if(!user)redirect('/sign-in');if(!membership)notFound();const input=await searchParams,propertyId=input.property;
 if(typeof propertyId!=='string'||!/^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(propertyId))notFound();
 const property=await client.from('properties').select('id,name,area').eq('id',propertyId).eq('organization_id',membership.organization_id).maybeSingle();if(property.error)throw new Error('Unable to verify property access.');if(!property.data)notFound();
 const page=typeof input.unitPage==='string'&&/^\d{1,5}$/.test(input.unitPage)?Math.max(1,Number(input.unitPage)):1,href=(next:number)=>`/staff/preventive-plans/new?property=${propertyId}&unitPage=${next}`;
 const query=(head=false)=>client.from('units').select('id,unit_label',{head,count:'exact'}).eq('property_id',propertyId);
 const count=await query(true);if(count.error)throw new Error('Unable to count property units.');const pages=Math.max(1,Math.ceil((count.count||0)/25));if(page>pages)redirect(href(pages));
 const units=await query().order('unit_label').order('id').range((page-1)*25,page*25-1);if(units.error)throw new Error('Unable to load property units.');
 return <><SiteHeader/><main className="account-layout"><section className="account-card"><p className="eyebrow">Preventive maintenance plan</p><h1>{property.data.name}</h1><p>{property.data.area}</p><p>Select a unit on this page, or create a common-area / whole-property plan. Browse unit pages before completing the form.</p><PreventivePlanEditor key={`${propertyId}-${page}`} action="create" propertyId={propertyId} units={units.data||[]}/><nav className="results-toolbar" aria-label="Property unit pages">{page>1?<a href={href(page-1)}>← Previous units</a>:<span/>}<span>{count.count||0} units · Page {page} of {pages}</span>{page<pages?<a href={href(page+1)}>More units →</a>:<span/>}</nav><a href="/staff/preventive-plans">Back to preventive plans ↗</a></section></main></>;
}
