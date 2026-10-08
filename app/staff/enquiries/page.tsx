import {redirect} from 'next/navigation';
import {SiteHeader} from '@/components/discovery/site-header';
import {catalogAccess} from '@/lib/staff/access';
import {StaffInbox} from '@/components/enquiries/staff-inbox';
import {inboxQuery,inboxHref,INBOX_PAGE_SIZE} from '@/lib/enquiries/inbox-query';
export const dynamic='force-dynamic';
export default async function Enquiries({searchParams}:{searchParams:Promise<Record<string,string|string[]|undefined>>}){
 const filters=inboxQuery(await searchParams);
 const {client,user,membership}=await catalogAccess(['admin','realtor','manager']);if(!user)redirect('/sign-in');
 if(!membership)return <><SiteHeader/><main className="account-layout"><section className="account-card"><h1>Staff access required.</h1><p>An administrator must assign enquiry access to your organization.</p><a href="/account">Return to your account</a></section></main></>;
 const buildQuery=(head=false)=>{
  let query=client.from('enquiries').select('id,contact_name,contact_email,phone,message,status,created_at,listing_id,realtor_id',{head,count:'exact'}).eq('organization_id',membership.organization_id);
  if(filters.status!=='all')query=query.eq('status',filters.status);
  return query;
 };
 const [{count,error:countError},{data:staff,error:staffError}]=await Promise.all([buildQuery(true),client.rpc('enquiry_staff_directory')]);
 const totalPages=Math.max(1,Math.ceil((count||0)/INBOX_PAGE_SIZE));
 if(!countError&&filters.page>totalPages)redirect(inboxHref(filters,totalPages));
 const {data,error}=countError?{data:null,error:countError}:await buildQuery().order('created_at',{ascending:false}).order('id').range((filters.page-1)*INBOX_PAGE_SIZE,filters.page*INBOX_PAGE_SIZE-1);
 const ids=data?.map(row=>row.id)||[];
 const {data:assignments,error:assignmentError}=ids.length?await client.from('enquiry_assignments').select('enquiry_id,assignee_user_id,version').eq('organization_id',membership.organization_id).in('enquiry_id',ids):{data:[],error:null};
 return <><SiteHeader/><main className="listing-workspace"><section className="page-intro"><p className="eyebrow">STAFF ENQUIRIES</p><h1>Connections start here.</h1><p>Follow up on your organization’s property enquiries and realtor introductions.</p><a href="/workspace">Team workspace ↗</a> · <a href="/staff">Catalog ↗</a> · <a href="/staff/viewings">Viewing calendar ↗</a> · <a href="/staff/sellers">Seller reviews ↗</a> · <a href="/staff/applications">Applications ↗</a></section>{error||staffError||assignmentError?<p role="alert">Unable to load enquiries. Please refresh.</p>:<><form className="filter-bar" action="/staff/enquiries" method="get"><label>Enquiry status<select name="status" defaultValue={filters.status}><option value="all">All enquiries</option><option value="new">New</option><option value="contacted">Contacted</option><option value="closed">Closed</option></select></label><button type="submit">Filter enquiries</button><p role="status">{count||0} matching enquiries · Page {filters.page} of {totalPages}</p></form><StaffInbox enquiries={data||[]} staff={staff||[]} assignments={assignments||[]}/>{totalPages>1&&<nav className="results-toolbar" aria-label="Enquiry result pages">{filters.page>1?<a href={inboxHref(filters,filters.page-1)}>← Previous</a>:<span/>}<span>Page {filters.page} of {totalPages}</span>{filters.page<totalPages?<a href={inboxHref(filters,filters.page+1)}>Next →</a>:<span/>}</nav>}</>}</main></>;
}
