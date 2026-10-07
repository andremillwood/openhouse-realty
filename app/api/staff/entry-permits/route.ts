import {NextRequest, NextResponse} from 'next/server';
import {catalogAccess} from '@/lib/staff/access';
import {sameOrigin} from '@/lib/http/origin';
import {boundedText} from '@/lib/http/body';
import {entryPermitInput} from '@/lib/staff/entry-permit-validation';
export async function POST(request: NextRequest) {
  if (!sameOrigin(request)) return NextResponse.json({error: 'Invalid request origin.'}, {status: 403});
  if (!request.headers.get('content-type')?.includes('application/json')) return NextResponse.json({error: 'JSON required.'}, {status: 415});
  const {client, user, membership} = await catalogAccess(['admin','manager']);
  if (!user) return NextResponse.json({error: 'Verified sign-in required.'}, {status: 401});
  if (!membership) return NextResponse.json({error: 'Organization management required.'}, {status: 403});
  let body;
  try {body = await boundedText(request, 8000);} catch {return NextResponse.json({error: 'Request too large.'}, {status: 413});}
  let input;
  try {input = entryPermitInput(JSON.parse(body));} catch (error) {return NextResponse.json({error: error instanceof Error ? error.message : 'Check the entry authorization details.'}, {status: 400});}
  const {data, error} = await client.rpc('manage_entry_permit', input);
  if (error) {
    const status = error.code === '42501' ? 403 : ['40001','40P01','23505'].includes(error.code) ? 409 : 400;
    return NextResponse.json({error: status === 409 ? 'The entry authorization or appointment changed. Refresh before retrying.' : 'Unable to update entry authorization. Check your access, approval and appointment window.'}, {status});
  }
  return NextResponse.json(data, {headers: {'Cache-Control': 'private, no-store'}});
}
