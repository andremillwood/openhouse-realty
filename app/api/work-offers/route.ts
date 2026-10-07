import {NextRequest, NextResponse} from 'next/server';
import {catalogAccess} from '@/lib/staff/access';
import {sameOrigin} from '@/lib/http/origin';
import {boundedText} from '@/lib/http/body';
import {workOfferInput} from '@/lib/staff/work-offer-validation';

export async function POST(request: NextRequest) {
  if (!sameOrigin(request)) return NextResponse.json({error: 'Invalid request origin.'}, {status: 403});
  if (!request.headers.get('content-type')?.includes('application/json')) return NextResponse.json({error: 'JSON required.'}, {status: 415});
  const {client, user, membership} = await catalogAccess(['admin', 'manager']);
  if (!user) return NextResponse.json({error: 'Verified sign-in required.'}, {status: 401});
  let body;
  try { body = await boundedText(request, 18000); } catch { return NextResponse.json({error: 'Request too large.'}, {status: 413}); }
  let input;
  try { input = workOfferInput(JSON.parse(body)); } catch (error) { return NextResponse.json({error: error instanceof Error ? error.message : 'Check the work offer.'}, {status: 400}); }
  if (['offer', 'withdraw'].includes(input.p_action) && !membership) return NextResponse.json({error: 'Organization management required.'}, {status: 403});
  // Contractor identity and organization authority are checked again by the database.
  const {data, error} = await client.rpc('manage_contractor_work_offer', input);
  if (error) {
    const status = error.code === '42501' ? 403 : ['40001', '40P01', '23505'].includes(error.code) ? 409 : 400;
    return NextResponse.json({error: status === 409 ? 'The offer or work order changed. Refresh before retrying.' : 'Unable to update this offer. Check your current access and the approved details.'}, {status});
  }
  return NextResponse.json(data, {headers: {'Cache-Control': 'private, no-store'}});
}
