import { NextRequest, NextResponse } from 'next/server';
import { catalogAccess } from '@/lib/staff/access';
import { sameOrigin } from '@/lib/http/origin';
import { boundedText } from '@/lib/http/body';
import { invoiceInput } from '@/lib/finance/invoice-validation';
const headers = { 'Cache-Control': 'private, no-store' };
export async function POST(request: NextRequest) {
  if (!sameOrigin(request)) return NextResponse.json({ error: 'Invalid request origin.' }, { status: 403, headers });
  if (!request.headers.get('content-type')?.includes('application/json')) return NextResponse.json({ error: 'JSON required.' }, { status: 415, headers });
  const { client, user, membership } = await catalogAccess(['admin','manager','finance']);
  if (!user) return NextResponse.json({ error: 'Verified sign-in required.' }, { status: 401, headers });
  if (!membership) return NextResponse.json({ error: 'Organization invoice staff required.' }, { status: 403, headers });
  let body;
  try { body = await boundedText(request, 5000); }
  catch { return NextResponse.json({ error: 'Request too large.' }, { status: 413, headers }); }
  let input;
  try { input = invoiceInput(JSON.parse(body)); }
  catch (error) { return NextResponse.json({ error: error instanceof Error ? error.message : 'Check the invoice details.' }, { status: 400, headers }); }
  if (input.p_action !== 'submit' && !['admin','finance'].includes(membership.role)) return NextResponse.json({ error: 'Finance review authority required.' }, { status: 403, headers });
  const { data, error } = await client.rpc('manage_vendor_invoice', input);
  if (error) {
    const status = error.code === '42501' ? 403 : ['40001', '40P01', '23505'].includes(error.code) ? 409 : ['22023', '22P02', '23503'].includes(error.code) ? 400 : 503;
    const message = status === 409 ? 'Invoice changed, the transition is unavailable, or this vendor invoice is already registered. Review needs a certified vendor invoice and no unfinished uploads. Refresh before retrying.' : status === 503 ? 'Invoice could not be saved. Retry the same request.' : 'Check the approved invoice, current revision, property binding and independent reviewer or approver.';
    return NextResponse.json({ error: message }, { status, headers });
  }
  return NextResponse.json(data, { headers });
}
