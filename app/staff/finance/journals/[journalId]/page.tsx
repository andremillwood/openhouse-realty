import {notFound, redirect} from 'next/navigation';
import {catalogAccess} from '@/lib/staff/access';
import {SiteHeader} from '@/components/discovery/site-header';
import {ReversalEditor} from '@/components/finance/reversal-editor';
import {formatJmdMinor} from '@/lib/finance/money';
export const dynamic = 'force-dynamic';
export default async function JournalDetail({params}: {params: Promise<{journalId: string}>}) {
  const {client, user, membership} = await catalogAccess(['admin', 'finance']);
  if (!user) redirect('/sign-in');if (!membership) notFound();
  const {journalId} = await params;
  if (!/^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(journalId)) notFound();
  const {data: journal, error} = await client.from('finance_journals').select('id,memo,reason,currency,posted_by,posted_at,request_id').eq('id', journalId).eq('organization_id', membership.organization_id).maybeSingle();
  if (error) throw new Error('Unable to load journal.');if (!journal) notFound();
  const {data: lines, error: lineError} = await client.from('finance_journal_lines').select('id,line_number,account_id,property_id,unit_id,debit_minor,credit_minor,finance_accounts(code,name)').eq('journal_id', journalId).eq('organization_id', membership.organization_id).order('line_number');
  if (lineError || !lines || lines.length < 2) throw new Error('Unable to load complete journal lines.');
  const [outgoing, incoming] = await Promise.all([
    client.from('finance_journal_reversals').select('original_journal_id,reversal_journal_id,reason,actor_user_id,created_at').eq('original_journal_id', journalId).eq('organization_id', membership.organization_id).maybeSingle(),
    client.from('finance_journal_reversals').select('original_journal_id,reversal_journal_id,reason,actor_user_id,created_at').eq('reversal_journal_id', journalId).eq('organization_id', membership.organization_id).maybeSingle()
  ]);
  if (outgoing.error || incoming.error) throw new Error('Unable to load reversal history.');
  const debit = lines.reduce((total, line) => total+BigInt(line.debit_minor), 0n), credit = lines.reduce((total, line) => total+BigInt(line.credit_minor), 0n);
  return <><SiteHeader/><main className="account-layout"><section className="account-card"><p className="eyebrow">Finance · Posted journal</p><h1>{journal.memo}</h1><p>Approval reason: {journal.reason}</p><p>Posted by {journal.posted_by} · {new Date(journal.posted_at).toLocaleString('en-JM', {timeZone: 'America/Jamaica'})} (Jamaica time)</p><p>Journal reference: {journal.id}</p><p>Request reference: {journal.request_id}</p>{lines.map(line => {const account = Array.isArray(line.finance_accounts) ? line.finance_accounts[0] : line.finance_accounts;return <article className="staff-editor" key={line.id}><h2>Line {line.line_number} · {account?.code || line.account_id}</h2><p>{account?.name}</p><p>Debit {formatJmdMinor(BigInt(line.debit_minor))} · Credit {formatJmdMinor(BigInt(line.credit_minor))}</p>{line.property_id && <p>Property reference: {line.property_id}</p>}{line.unit_id && <p>Unit reference: {line.unit_id}</p>}</article>;})}<p>Debits {formatJmdMinor(debit)} · Credits {formatJmdMinor(credit)} · {debit === credit ? 'Balanced' : 'Balance requires investigation'}</p>{outgoing.data ? <section><h2>Reversed</h2><p>{outgoing.data.reason}</p><a href={`/staff/finance/journals/${outgoing.data.reversal_journal_id}`}>Review reversal journal</a></section> : incoming.data ? <section><h2>Reversal journal</h2><p>{incoming.data.reason}</p><a href={`/staff/finance/journals/${incoming.data.original_journal_id}`}>Review original journal</a></section> : <ReversalEditor journalId={journal.id}/>}<a href="/staff/finance/journals">Journal history</a></section></main></>;
}
