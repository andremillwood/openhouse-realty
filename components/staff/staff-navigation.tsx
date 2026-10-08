import {catalogAccess} from '@/lib/staff/access';
const tools = [
  {href: '/staff/lease-reviews', label: 'Unanswered lease questions', roles: ['admin','realtor','manager']},
  {href: '/staff/reports/contractors', label: 'Contractor coordination report', roles: ['admin','manager']},
  {href: '/staff/reports/maintenance', label: 'Maintenance workload report', roles: ['admin','manager']},
  {href: '/staff/reports/demand', label: 'Demand workload report', roles: ['admin','realtor','manager']},
  {href: '/staff', label: 'Property and realtor catalog', roles: ['admin','realtor']},
  {href: '/staff/enquiries', label: 'Enquiries', roles: ['admin','realtor','manager']},
  {href: '/staff/viewings', label: 'Viewings', roles: ['admin','realtor','manager']},
  {href: '/staff/sellers', label: 'Seller reviews', roles: ['admin','realtor','manager']},
  {href: '/staff/applications', label: 'Rental applications', roles: ['admin','realtor','manager']},
  {href: '/staff/properties', label: 'Managed properties and units', roles: ['admin','realtor','manager']},
  {href: '/staff/open-houses', label: 'Open-house schedule', roles: ['admin','realtor','manager']},
  {href: '/staff/notifications', label: 'Notification monitor', roles: ['admin','realtor','manager']},
  {href: '/staff/work-orders', label: 'Maintenance work orders', roles: ['admin','manager']},
  {href: '/staff/preventive-plans', label: 'Preventive maintenance plans', roles: ['admin','manager']},
  {href: '/staff/contractors', label: 'Contractor registrations', roles: ['admin','manager']},
  {href: '/staff/application-policy', label: 'Rental approval policy', roles: ['admin']},
  {href: '/staff/lease-templates', label: 'Approved lease templates', roles: ['admin']},
  {href: '/staff/owner-access', label: 'Owner portfolio access', roles: ['admin']},
  {href: '/staff/memberships', label: 'Team access', roles: ['admin']},
  {href: '/staff/invitations', label: 'Team invitations', roles: ['admin']},
  {href: '/staff/finance/invoices', label: 'Vendor invoices', roles: ['admin','manager','finance']},
  {href: '/staff/finance/cheques', label: 'Incoming cheque custody', roles: ['admin','finance']},
  {href: '/staff/finance/accounts', label: 'Finance account register', roles: ['admin','finance']},
  {href: '/staff/finance/journals', label: 'Journal posting and history', roles: ['admin','finance']},
  {href: '/staff/finance/trial-balance', label: 'Trial balance', roles: ['admin','finance']},
  {href: '/security', label: 'Check property entry permits', roles: ['security']}
];
const groups=[
 {title:'Prospects and property',description:'Manage your catalog, conversations and appointments.',matches:(href:string)=>['/staff','/staff/enquiries','/staff/viewings','/staff/sellers','/staff/applications','/staff/open-houses','/staff/reports/demand','/staff/lease-reviews'].includes(href)},
 {title:'Property management',description:'Coordinate properties, maintenance and contractor work.',matches:(href:string)=>['/staff/properties','/staff/work-orders','/staff/preventive-plans','/staff/contractors','/staff/reports/contractors','/staff/reports/maintenance','/security'].includes(href)},
 {title:'Finance',description:'Review evidence, custody and retained financial records.',matches:(href:string)=>href.startsWith('/staff/finance/')},
 {title:'Team and controls',description:'Manage approved access, policies and delivery monitoring.',matches:(href:string)=>['/staff/notifications','/staff/application-policy','/staff/lease-templates','/staff/owner-access','/staff/memberships','/staff/invitations'].includes(href)},
];
export async function StaffNavigation() {
  const {user, membership} = await catalogAccess(['admin','realtor','manager','finance','security']);
  if (!user || !membership) return null;
  const allowed=tools.filter(tool=>tool.roles.includes(membership.role));
  return <section className="team-tools"><h2>Your team tools</h2><a href="/workspace">Open team workspace ↗</a><nav className="team-tool-grid" aria-label="Team tools">{groups.map(group=>{const links=allowed.filter(tool=>group.matches(tool.href));return links.length?<section className="team-tool-group" key={group.title}><h3>{group.title}</h3><p>{group.description}</p><ul>{links.map(tool=><li key={tool.href}><a href={tool.href}>{tool.label} ↗</a></li>)}</ul></section>:null;})}</nav></section>;
}
