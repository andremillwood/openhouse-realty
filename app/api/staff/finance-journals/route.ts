import {NextRequest, NextResponse} from 'next/server';
import {catalogAccess} from '@/lib/staff/access';
import {sameOrigin} from '@/lib/http/origin';
import {boundedText} from '@/lib/http/body';
import {journalInput} from '@/lib/finance/journal-validation';
export async function POST(request: NextRequest) {
  if (!sameOrigin(request)) return NextResponse.json({error: 'Invalid request origin.'}, {status: 403});
  if (!request.headers.get('content-type')?.includes('application/json')) return NextResponse.json({error: 'JSON required.'}, {status: 415});
  const {client, user, membership} = await catalogAccess(['admin', 'finance']);
  if (!user) return NextResponse.json({error: 'Verified sign-in required.'}, {status: 401});
  if (!membership) return NextResponse.json({error: 'Organization finance access required.'}, {status: 403});
  let body;
  try {body = await boundedText(request, 80000);} catch {return NextResponse.json({error: 'Request too large.'}, {status: 413});}
  let input;
  try {input = journalInput(JSON.parse(body));} catch (error) {return NextResponse.json({error: error instanceof Error ? error.message : 'Check the approved journal details.'}, {status: 400});}
  const {data, error} = await client.rpc('post_finance_journal', {p_request_id: input.request_id, p_currency: input.currency, p_memo: input.memo, p_reason: input.reason, p_approved: input.approved, p_lines: input.lines});
  if (error) {
    const status = error.code === '42501' ? 403 : ['40001', '40P01', '23505'].includes(error.code) ? 409 : ['22023', '22P02', '23503'].includes(error.code) ? 400 : 503;
    return NextResponse.json({error: status === 503 ? 'Posting is temporarily unavailable. Retry the same submission.' : status === 409 ? 'The posting conflicts with another change. Refresh and review the journal register.' : 'Unable to post the journal. Check your access, approved accounts and balanced amounts.'}, {status});
  }
  return NextResponse.json({id: data}, {headers: {'Cache-Control': 'private, no-store'}});
}
