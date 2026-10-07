import {notFound,redirect} from 'next/navigation';
import {catalogAccess} from '@/lib/staff/access';
import {SiteHeader} from '@/components/discovery/site-header';
import {MembershipEditor,type StaffMember} from '@/components/staff/membership-editor';
export const dynamic='force-dynamic';
export default async function Memberships({searchParams}:{searchParams:Promise<Record<string,string|string[]|undefined>>}){
 const {client,user,membership}=await catalogAccess(['admin']);if(!user)redirect('/sign-in');if(!membership)notFound();const input=await searchParams;
 const page=typeof input.page==='string'&&/^\d{1,5}$/.test(input.page)?Math.max(1,Number(input.page)):1;
 const response=await client.rpc('staff_membership_directory',{p_page:page});if(response.error)throw new Error('Unable to load organization memberships.');
 const directory=response.data as {rows:StaffMember[];total:number;page:number;pages:number};if(directory.page!==page)redirect(`/staff/memberships?page=${directory.page}`);
 return <><SiteHeader/><main className="account-layout"><section className="account-card"><p className="eyebrow">Organization administration</p><h1>Your staff access.</h1><p>Assign accounts after they sign up and verify their email. These roles authorize the implemented organization workflows; they do not create resident, contractor or owner access.</p><p>Keep another verified administrator before revoking or changing an administrator’s role. Revocation removes staff access on subsequent authorization checks; it does not sign the person out of their prospect account or undo earlier work.</p>{input.saved==='1'&&<p role="status">Staff access updated.</p>}<p><a href="/staff/memberships/history">Review membership changes ↗</a> · <a href="/staff">Staff catalog ↗</a></p><p><a href="/staff/invitations">Invite a new team member →</a></p><MembershipEditor/>{directory.rows.map(member=><MembershipEditor key={`${member.user_id}-${member.membership_revision}`} member={member}/>)}<nav className="results-toolbar" aria-label="Staff membership pages">{page>1?<a href={`/staff/memberships?page=${page-1}`}>← Previous</a>:<span/>}<span>{directory.total} members · Page {page} of {directory.pages}</span>{page<directory.pages?<a href={`/staff/memberships?page=${page+1}`}>Next →</a>:<span/>}</nav></section></main></>;
}
