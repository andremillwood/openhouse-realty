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
export async function StaffNavigation() {
  const {user, membership} = await catalogAccess(['admin','realtor','manager','finance','security']);
  if (!user || !membership) return null;
  return <section><h2>Your team tools</h2><nav aria-label="Team tools"><ul>{tools.filter(tool => tool.roles.includes(membership.role)).map(tool => <li key={tool.href}><a href={tool.href}>{tool.label}</a></li>)}</ul></nav></section>;
}
