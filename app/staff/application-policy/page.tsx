import {notFound,redirect} from 'next/navigation';
import {createClient} from '@/lib/supabase/server';
import {SiteHeader} from '@/components/discovery/site-header';
import {PolicyEditor} from '@/components/applications/approval';
export const dynamic='force-dynamic';
export default async function RentalPolicy(){
 const client=await createClient();const {data:{user},error}=await client.auth.getUser();if(error||!user?.email_confirmed_at)redirect('/sign-in');
 const {data:membership}=await client.from('staff_accounts').select('organization_id,role').eq('user_id',user.id).maybeSingle();if(!membership||membership.role!=='admin')notFound();
 const {data:policies,error:policyError}=await client.from('rental_approval_policies').select('id,version,required_document_kinds,required_cosigners,approver_roles,policy_reference,created_at').eq('organization_id',membership.organization_id).order('version',{ascending:false}).limit(25);if(policyError)throw new Error('Unable to load business policies.');const policy=policies?.[0]||null;
 return <><SiteHeader/><main className="account-layout"><section className="account-card"><p className="eyebrow">Organization administrator</p><h1>Rental approval policy</h1><p>Record the business’s approved requirements and eligibility process. No policy is pre-approved. Each change creates a new version; staff approval must use the current version.</p><PolicyEditor key={policy?.version||0} policy={policy}/><h2>Latest 25 approved policy versions</h2>{policies?.map(row=><article key={row.id}><strong>Version {row.version}</strong><p className="enquiry-message">{row.policy_reference}</p><p>{row.required_document_kinds.join(', ')||'No document categories'} · {row.required_cosigners} co-signers · {row.approver_roles.join(', ')}</p></article>)}<a href="/staff/applications">Application inbox ↗</a></section></main></>;
}
