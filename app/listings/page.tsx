import { SiteHeader } from '@/components/discovery/site-header';
import { createClient } from '@/lib/supabase/server';
import { LiveCatalog } from '@/components/discovery/live-catalog';
import { redirect } from 'next/navigation';
import { catalogQuery, catalogHref, CATALOG_PAGE_SIZE } from '@/lib/discovery/catalog-query';
export const dynamic = 'force-dynamic';
export default async function Listings({ searchParams }: { searchParams: Promise<Record<string, string | string[] | undefined>> }) {
  const filters = catalogQuery(await searchParams);
  const client = await createClient();
  const buildQuery = (head = false) => {
    let query = client.from('listings').select('id,title,area,intent,price_jmd,bedrooms,bathrooms,parking_spaces,size_sq_ft,description,photo_url,approximate_latitude,approximate_longitude,location_label', { count: 'exact', head }).eq('status', 'published');
    if (filters.intent !== 'all') query = query.eq('intent', filters.intent);
    if (filters.area) query = query.ilike('area', `%${filters.area}%`);
    if (filters.q) query = query.or(`title.ilike.%${filters.q}%,area.ilike.%${filters.q}%`);
    return query;
  };
  const [{ count, error: countError }, { data: { user } }] = await Promise.all([buildQuery(true), client.auth.getUser()]);
  const totalPages = Math.max(1, Math.ceil((count || 0) / CATALOG_PAGE_SIZE));
  if (!countError && filters.page > totalPages) redirect(catalogHref(filters, totalPages));
  const { data: listings, error: rowsError } = countError ? { data: null, error: countError } : await buildQuery().order('published_at', { ascending: false }).order('id').range((filters.page - 1) * CATALOG_PAGE_SIZE, filters.page * CATALOG_PAGE_SIZE - 1);
  const error = countError || rowsError;
  const { data: saves } = user && listings?.length ? await client.from('saved_listings').select('listing_id').eq('user_id', user.id).in('listing_id', listings.map(row => row.id)) : { data: [] };
  return <><SiteHeader /><main><section className="page-intro"><p className="eyebrow">OPEN HOUSE REALTY · LIVE INVENTORY</p><h1>Find your next chapter.</h1><p>Published properties from the Open House team. Saves stay with your verified account.</p><p><a className="button-link" href="/demo/listings">Explore 12 clearly labelled demo properties and maps ↗</a></p></section><section className="listing-workspace">{error ? <div className="empty-state"><h2>Properties are unavailable</h2><p>Please try again shortly.</p></div> : <LiveCatalog key={catalogHref(filters, filters.page)} filters={filters} total={count || 0} totalPages={totalPages} listings={listings || []} savedIds={saves?.map(row => row.listing_id) || []} />}</section></main></>;
}
