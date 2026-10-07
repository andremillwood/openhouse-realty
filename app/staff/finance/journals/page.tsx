import {notFound, redirect} from 'next/navigation';
import {catalogAccess} from '@/lib/staff/access';
import {SiteHeader} from '@/components/discovery/site-header';
import {JournalEditor} from '@/components/finance/journal-editor';
export const dynamic = 'force-dynamic';
export default async function JournalPosting({searchParams}: {searchParams: Promise<Record<string, string | string[] | undefined>>}) {
  const {client, user, membership} = await catalogAccess(['admin', 'finance']);
  if (!user) redirect('/sign-in');
  if (!membership) notFound();
  const input = await searchParams;
  const page = typeof input.page === 'string' && /^\d{1,5}$/.test(input.page) ? Math.max(1, Number(input.page)) : 1;
  const query = (head = false) => client.from('finance_journals').select('id,memo,reason,posted_by,posted_at,currency', {head, count: 'exact'}).eq('organization_id', membership.organization_id);
  const count = await query(true);if (count.error) throw new Error('Unable to count journals.');
  const pages = Math.max(1, Math.ceil((count.count || 0)/25));if (page > pages) redirect(`/staff/finance/journals?page=${pages}`);
  const rows = await query().order('posted_at', {ascending: false}).order('id').range((page-1)*25, page*25-1);
  return <><SiteHeader/><main className="account-layout"><section className="account-card"><p className="eyebrow">Finance</p><h1>Journal posting</h1><p>Approved postings are immutable. Review all amounts and account references before submitting.</p><JournalEditor/><h2>Posting history</h2>{rows.error ? <p role="alert">Unable to load journals. Please refresh.</p> : rows.data?.length ? rows.data.map(journal => <article className="staff-editor" key={journal.id}><h3>{journal.memo}</h3><p>{journal.reason}</p><p>{new Date(journal.posted_at).toLocaleString('en-JM', {timeZone: 'America/Jamaica'})} (Jamaica time)</p><a href={`/staff/finance/journals/${journal.id}`}>Review journal</a></article>) : <p>No journals posted.</p>}<nav aria-label="Journal history pages">{page > 1 && <a href={`/staff/finance/journals?page=${page-1}`}>Previous</a>}<span> · Page {page} of {pages} · </span>{page < pages && <a href={`/staff/finance/journals?page=${page+1}`}>Next</a>}</nav><p><a href="/staff/finance/accounts">Approved account register</a> · <a href="/account">My account</a></p></section></main></>;
}
