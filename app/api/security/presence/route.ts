import {NextRequest, NextResponse} from 'next/server';
import {createClient} from '@/lib/supabase/server';
import {sameOrigin} from '@/lib/http/origin';
import {boundedText} from '@/lib/http/body';
import {presenceInput} from '@/lib/security/presence-validation';

export async function POST(request: NextRequest) {
  if (!sameOrigin(request)) return NextResponse.json({error: 'Invalid request origin.'}, {status: 403});
  if (!request.headers.get('content-type')?.includes('application/json')) return NextResponse.json({error: 'JSON required.'}, {status: 415});
  const client = await createClient();
  const {data: {user}, error: authError} = await client.auth.getUser();
  if (authError || !user?.email_confirmed_at) return NextResponse.json({error: 'Verified sign-in required.'}, {status: 401});
  let body;
  try {body = await boundedText(request, 5000);} catch {return NextResponse.json({error: 'Request too large.'}, {status: 413});}
  let input;
  try {input = presenceInput(JSON.parse(body));} catch (error) {return NextResponse.json({error: error instanceof Error ? error.message : 'Check the presence request.'}, {status: 400});}
  // The RPC derives property authority and actor identity from the current account.
  const {data, error} = await client.rpc('record_contractor_presence', input);
  if (error) {
    const status = error.code === '42501' ? 403 : ['40001', '40P01', '23505'].includes(error.code) ? 409 : 400;
    const message = status === 403 ? 'Current security assignment for this property required.' : status === 409 ? 'The permit, visit or presence changed. Refresh before retrying.' : 'Unable to record presence. Check the permit window, identity check and reason.';
    return NextResponse.json({error: message}, {status});
  }
  return NextResponse.json(data, {headers: {'Cache-Control': 'private, no-store'}});
}
