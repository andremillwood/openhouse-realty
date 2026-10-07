import {notFound, redirect} from 'next/navigation';
import {catalogAccess} from '@/lib/staff/access';
import {SiteHeader} from '@/components/discovery/site-header';
import {SecurityAssignmentEditor} from '@/components/staff/security-assignment-editor';
export const dynamic = 'force-dynamic';
export default async function Security({params, searchParams}: {params: Promise<{propertyId: string}>; searchParams: Promise<Record<string, string|string[]|undefined>>}) {
  const {client, user, membership} = await catalogAccess(['admin','manager']); if (!user) redirect('/sign-in'); if (!membership) notFound();
  const {propertyId} = await params, input = await searchParams;
  if (!/^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(propertyId)) notFound();
  const property = await client.from('properties').select('id,name').eq('id', propertyId).eq('organization_id', membership.organization_id).maybeSingle();
  if (property.error) throw new Error('Unable to load property.'); if (!property.data) notFound();
  const page = typeof input.page === 'string' && /^\d{1,5}$/.test(input.page) ? Math.max(1, Number(input.page)) : 1;
  const href = (next: number) => `/staff/security/${propertyId}?page=${next}`;
  const query = (head = false) => client.from('property_security_assignments').select('id,user_id,is_active,version', {head, count: 'exact'}).eq('organization_id', membership.organization_id).eq('property_id', propertyId);
  const count = await query(true); if (count.error) throw new Error('Unable to count security assignments.'); const pages = Math.max(1, Math.ceil((count.count || 0)/25)); if (page > pages) redirect(href(pages));
  const rows = await query().order('created_at', {ascending: false}).order('id').range((page-1)*25, page*25-1);
  return <><SiteHeader/><main className="account-layout"><section className="account-card"><p className="eyebrow">Property security register</p><h1>{property.data.name}</h1><p>Approve verified security accounts for this property. Assignment does not grant access to internal work or resident records.</p><SecurityAssignmentEditor propertyId={propertyId}/>{rows.error ? <p role="alert">Unable to load assignments. Please refresh.</p> : rows.data?.length ? rows.data.map(row => <article className="staff-editor" key={row.id}><h2><a href={`/staff/security/assignments/${row.id}`}>Security account {row.user_id}</a></h2><p>{row.is_active ? 'Active' : 'Inactive'} · Revision {row.version}</p></article>) : <p>No approved security accounts for this property.</p>}<nav className="results-toolbar" aria-label="Security assignment pages">{page > 1 ? <a href={href(page-1)}>← Previous</a> : <span/>}<span>{count.count || 0} assignments · Page {page} of {pages}</span>{page < pages ? <a href={href(page+1)}>Next →</a> : <span/>}</nav><a href={`/staff/properties?property=${propertyId}`}>Back to managed property</a></section></main></>;
}
