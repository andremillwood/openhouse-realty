import {notFound,redirect} from 'next/navigation';
import {catalogAccess} from '@/lib/staff/access';
import {SiteHeader} from '@/components/discovery/site-header';
import {OwnerAccessEditor} from '@/components/staff/owner-access-editor';
export const dynamic='force-dynamic';
export default async function OwnerAccess({searchParams}:{searchParams:Promise<Record<string,string|string[]|undefined>>}) {
 const {client,user,membership}=await catalogAccess(['admin']);if(!user)redirect('/sign-in');if(!membership)notFound();
 const input=await searchParams,property=typeof input.property==='string'?input.property:'',page=typeof input.page==='string'&&/^\d{1,5}$/.test(input.page)?Math.max(1,Number(input.page)):1;
 const uuid=/^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
 if(!property)return <><SiteHeader/><main className="account-layout"><section className="account-card"><h1>Owner portfolio access</h1><p>Select a managed property to review its approved owner accounts.</p><a href="/staff/properties">Choose a managed property →</a></section></main></>;
 if(!uuid.test(property))notFound();
 const selected=await client.from('properties').select('id,name').eq('organization_id',membership.organization_id).eq('id',property).maybeSingle();
 if(selected.error)throw new Error('Unable to load the managed property.');if(!selected.data)notFound();
 const href=(next:number)=>`/staff/owner-access?property=${property}&page=${next}`;
 const query=(head=false)=>client.from('owner_property_access').select('id,user_id,is_active,version',{head,count:'exact'}).eq('organization_id',membership.organization_id).eq('property_id',property);
 const count=await query(true);if(count.error)throw new Error('Unable to count owner access records.');const pages=Math.max(1,Math.ceil((count.count||0)/25));if(page>pages)redirect(href(pages));
 const rows=await query().order('created_at',{ascending:false}).order('id').range((page-1)*25,page*25-1);
 return <><SiteHeader/><main className="account-layout"><section className="account-card"><p className="eyebrow">Administrator approval</p><h1>{selected.data.name}: owner access</h1><p>Approve verified accounts for this property. Revoking access removes portfolio reporting access. This register records permission; it does not establish legal title or ownership shares.</p><OwnerAccessEditor propertyId={property}/><h2>Approved account register</h2>{rows.error?<p role="alert">Unable to load access records. Refresh before making changes.</p>:rows.data?.length?rows.data.map(row=><article key={row.id}><h3>{row.is_active?'Active access':'Revoked access'}</h3><OwnerAccessEditor propertyId={property} access={row}/><a href={`/staff/owner-access/${row.id}`}>Approval history →</a></article>):<p>No approved owner accounts for this property.</p>}<nav className="results-toolbar" aria-label="Owner access pages">{page>1?<a href={href(page-1)}>← Previous</a>:<span/>}<span>{count.count||0} access records · Page {page} of {pages}</span>{page<pages?<a href={href(page+1)}>Next →</a>:<span/>}</nav><a href="/staff/properties">Managed properties →</a></section></main></>;
}
