import { sameOrigin } from '@/lib/http/origin';
import { NextRequest, NextResponse } from 'next/server';
import { catalogAccess } from '@/lib/staff/access';
import { boundedText } from '@/lib/http/body';
import { catalogInput } from '@/lib/staff/catalog-validation';
export async function POST(request: NextRequest) {
  if (!sameOrigin(request)) return NextResponse.json({ error: 'Invalid request origin.' }, { status: 403 });
  if (!request.headers.get('content-type')?.includes('application/json')) return NextResponse.json({ error: 'JSON required.' }, { status: 415 });
  const { client, user, membership } = await catalogAccess();
  if (!user) return NextResponse.json({ error: 'Sign in first.' }, { status: 401 });
  if (!membership) return NextResponse.json({ error: 'Catalog staff access required.' }, { status: 403 });
  let body: string;
  try { body = await boundedText(request, 20000); } catch { return NextResponse.json({ error: 'Record too large or unreadable.' }, { status: 413 }); }
  let input;
  try { input = catalogInput(JSON.parse(body)); } catch (error) { return NextResponse.json({ error: error instanceof Error ? error.message : 'Invalid record.' }, { status: 400 }); }
  if(input.kind==='realtor'){
    const {data,error}=await client.rpc('author_realtor_profile',{p_request_id:input.request_id,p_profile_id:input.id||null,p_expected_revision:input.expected_revision,p_record:input.record,p_reason:input.reason,p_approved:input.approved});
    if(error){const status=error.code==='42501'?403:['40001','40P01','23505'].includes(error.code)?409:400;return NextResponse.json({error:status===409?'This profile changed. Refresh before retrying.':'Unable to save this profile. Check the approved content, reason and organization access.'},{status});}
    return NextResponse.json(data,{headers:{'Cache-Control':'private, no-store'}});
  }
  const table = input.kind === 'listing' ? 'listings' : 'realtor_profiles';
  const record: Record<string, unknown> = { ...input.record, organization_id: membership.organization_id, ...(input.kind === 'listing' ? { updated_at: new Date().toISOString(), published_at: input.record.status === 'published' ? new Date().toISOString() : null } : {}) };
  const query = input.id ? client.from(table).update(record).eq('id', input.id).eq('organization_id', membership.organization_id) : client.from(table).insert(record);
  const { data, error } = await query.select('id').single();
  if (error) return NextResponse.json({ error: 'Unable to save. Check the record and your access, then retry.' }, { status: 400 });
  return NextResponse.json({ id: data.id }, { headers: { 'Cache-Control': 'no-store' } });
}
