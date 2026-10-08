import {redirect,notFound} from 'next/navigation';
import {SiteHeader} from '@/components/discovery/site-header';
import {StaffNavigation} from '@/components/staff/staff-navigation';
import {catalogAccess} from '@/lib/staff/access';
export const dynamic='force-dynamic';
export const metadata={title:'Team workspace | Open House Realty'};
export default async function Workspace(){
 const {user,membership}=await catalogAccess(['admin','realtor','manager','finance','security']);
 if(!user)redirect('/sign-in?next=%2Fworkspace');if(!membership)notFound();
 return <><SiteHeader/><main className="services-page"><section className="services-intro"><p className="eyebrow">OPEN HOUSE TEAM WORKSPACE</p><h1>A clear view of<br/>your next move.</h1><p>Choose the work you need to do. Your tools reflect your current team access; each workflow checks its own permissions.</p><a href="/account">Your personal account ↗</a></section><StaffNavigation/></main></>;
}
