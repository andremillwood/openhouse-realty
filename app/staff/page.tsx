import {uuidPattern} from '@/lib/enquiries/validation';
import {redirect,notFound} from 'next/navigation';
import {SiteHeader} from '@/components/discovery/site-header';
import {catalogAccess} from '@/lib/staff/access';
import {CatalogEditor} from '@/components/staff/catalog-editor';
export const dynamic='force-dynamic';
const listingFields='id,property_id,unit_id,management_revision,title,area,intent,property_type,status,price_jmd,bedrooms,bathrooms,parking_spaces,description,photo_url,approximate_latitude,approximate_longitude,location_label';
const realtorFields='id,display_name,bio,photo_url,service_areas,supported_intents,communication_style,guidance_style,decision_pace,is_published,authoring_revision';
export default async function Staff({searchParams}:{searchParams:Promise<Record<string,string|string[]|undefined>>}){
 const {client,user,membership}=await catalogAccess();
 if(!user)redirect('/sign-in');
 if(!membership)return <><SiteHeader/><main className="account-layout"><section className="account-card"><h1>Staff access required.</h1><p>An administrator must assign catalog access to your organization.</p><a href="/account">Return to your account</a></section></main></>;
 const input=await searchParams;
 for(const key of ['listing','realtor'])if(input[key]!==undefined&&(typeof input[key]!=='string'||!uuidPattern.test(input[key])))notFound();
 if(input.listing&&input.realtor)notFound();
 const kind=input.realtor||(!input.listing&&input.catalog==='realtor')?'realtor':'listing',target=(kind==='listing'?input.listing:input.realtor) as string|undefined;
 const q=typeof input.q==='string'?input.q.trim().slice(0,120):'',state=typeof input.state==='string'&&(kind==='listing'?['draft','published','paused']:['draft','published']).includes(input.state)?input.state:'';
 const page=!target&&typeof input.page==='string'&&/^\d{1,5}$/.test(input.page)?Math.max(1,Number(input.page)):1;
 const href=(next:number)=>{const params=new URLSearchParams({catalog:kind,page:String(next)});if(q)params.set('q',q);if(state)params.set('state',state);return `/staff?${params}`;};
 const query=(head=false)=>{
  let builder=client.from(kind==='listing'?'listings':'realtor_profiles').select(head?'id':kind==='listing'?listingFields:realtorFields,{head,count:'exact'}).eq('organization_id',membership.organization_id);
  if(target)return builder.eq('id',target);
  if(state)builder=kind==='listing'?builder.eq('status',state):builder.eq('is_published',state==='published');
  if(q)builder=builder.ilike(kind==='listing'?'title':'display_name',`%${q.replace(/[\\%_]/g,'\\$&')}%`);
  return builder;
 };
 const count=await query(true);if(count.error)throw new Error('Unable to count your catalog records.');if(target&&!count.count)notFound();
 const pages=Math.max(1,Math.ceil((count.count||0)/25));if(page>pages)redirect(href(pages));
 const result=await query().order('created_at',{ascending:false}).order('id').range((page-1)*25,page*25-1);
 const rows=((result.data as unknown[]|null)||[]).map(row=>{if(!row||typeof row!=='object'||!('id' in row)||typeof row.id!=='string')throw new Error('Invalid catalog response.');return row as Record<string,unknown>&{id:string};});
 if(!result.error&&target&&!rows.length)notFound();
 return <><SiteHeader/><main className="listing-workspace"><section className="page-intro"><p className="eyebrow">STAFF CATALOG</p><h1>Ready for a new chapter.</h1><p>Manage your organization’s approved property and realtor content.</p><a href="/workspace">Team workspace ↗</a> · <a href="/staff/work-orders">Work orders ↗</a> · <a href="/staff/memberships">Staff access ↗</a> · <a href="/staff/enquiries">Enquiry inbox ↗</a> · <a href="/staff/viewings">Viewing calendar ↗</a> · <a href="/staff/sellers">Seller reviews ↗</a> · <a href="/staff/properties">Private properties/units ↗</a>{target&&<> · <a href={`/staff?catalog=${kind}`}>Browse catalog ↗</a></>}{typeof input.saved==='string'&&['listing','realtor'].includes(input.saved)&&<p role="status">Catalog record saved.</p>}</section><nav className="results-toolbar" aria-label="Catalog type"><a href="/staff?catalog=listing" aria-current={kind==='listing'?'page':undefined}>Properties</a><a href="/staff?catalog=realtor" aria-current={kind==='realtor'?'page':undefined}>Realtors</a></nav>{!target&&<form className="filter-bar" action="/staff"><input type="hidden" name="catalog" value={kind}/><label>{kind==='listing'?'Property title':'Realtor name'}<input name="q" defaultValue={q} maxLength={120}/></label><label>Publication<select name="state" defaultValue={state}><option value="">All states</option><option value="draft">Draft</option><option value="published">Published</option>{kind==='listing'&&<option value="paused">Paused</option>}</select></label><button className="secondary">Find records</button><a href={`/staff?catalog=${kind}`}>Clear filters</a></form>}{result.error?<p role="alert">Unable to load catalog records. Please refresh.</p>:<><p>{count.count||0} {kind==='listing'?'properties':'realtor profiles'}{q||state?' matching these filters':''}. Choose a record below to edit it, or create a new draft.</p><CatalogEditor key={`${kind}-${target||page}-${q}-${state}`} initialListingId={target||''} initialKind={kind} listings={kind==='listing'?rows:[]} realtors={kind==='realtor'?rows:[]}/></>}{!target&&<nav className="results-toolbar" aria-label="Catalog pages">{page>1?<a href={href(page-1)}>← Previous</a>:<span/>}<span>Page {page} of {pages}</span>{page<pages?<a href={href(page+1)}>Next →</a>:<span/>}</nav>}</main></>;
}
