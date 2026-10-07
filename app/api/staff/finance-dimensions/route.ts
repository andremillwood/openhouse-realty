import {NextRequest, NextResponse} from 'next/server';
import {catalogAccess} from '@/lib/staff/access';
export async function GET(request: NextRequest) {
  const {client, user, membership} = await catalogAccess(['admin', 'finance']);
  if (!user) return NextResponse.json({error: 'Verified sign-in required.'}, {status: 401});
  if (!membership) return NextResponse.json({error: 'Organization finance access required.'}, {status: 403});
  const params = new URL(request.url).searchParams;
  const kind = params.get('kind'), term = (params.get('q') || '').trim(), property = params.get('property_id');
  if (!kind || !['property', 'unit'].includes(kind) || term.length > 120 || (kind === 'unit' && (!property || !/^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(property)))) return NextResponse.json({error: 'Check the search and selected property.'}, {status: 400});
  const {data, error} = await client.rpc('search_finance_dimensions', {p_kind: kind, p_term: term, p_property_id: kind === 'unit' ? property : null});
  if (error) return NextResponse.json({error: 'Unable to search property or unit labels.'}, {status: error.code === '42501' ? 403 : error.code === '22023' ? 400 : 503});
  return NextResponse.json(data, {headers: {'Cache-Control': 'private, no-store'}});
}
