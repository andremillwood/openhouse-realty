import {notFound,redirect} from 'next/navigation';
import {createClient} from '@/lib/supabase/server';
import {SiteHeader} from '@/components/discovery/site-header';
import {InvitationForm} from '@/components/staff/invitation-form';
export const dynamic='force-dynamic';
export default async function Invitation({params}:{params:Promise<{invitationId:string}>}){
 const {invitationId}=await params;if(!/^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(invitationId))notFound();
 const client=await createClient(),{data:{user},error}=await client.auth.getUser();if(error||!user?.email_confirmed_at)redirect('/sign-in');
 const response=await client.rpc('staff_invitation_summary',{p_invitation_id:invitationId});if(response.error)throw new Error('Unable to load the staff invitation.');if(!response.data)notFound();
 const row=response.data as {id:string;organization_name:string;invite_email:string;role:string;state:string;version:number;expires_at:string;can_accept:boolean;can_decline:boolean;blocked_reason:string|null};
 return <><SiteHeader/><main className="account-layout"><section className="account-card"><p className="eyebrow">Staff invitation</p><h1>Join {row.organization_name}.</h1><p>Approved role: <strong>{row.role}</strong><br/>Invited email: {row.invite_email}<br/>Status: {row.state}</p><p>Expires {new Date(row.expires_at).toLocaleString('en-JM',{timeZone:'America/Jamaica'})} · Jamaica time</p><p>Accepting gives this account the organization access associated with the approved role. Review the invitation with the team if you do not recognize it.</p>{row.blocked_reason&&<p role="status">{row.blocked_reason}</p>}{(row.can_accept||row.can_decline)&&<InvitationForm key={`${row.id}-${row.version}`} invitation={row} recipient/>}<p><a href="/account/invitations">Your invitations →</a> · <a href="/account">Your account and team tools →</a></p></section></main></>;
}
