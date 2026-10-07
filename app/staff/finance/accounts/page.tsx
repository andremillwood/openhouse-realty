import {notFound, redirect} from 'next/navigation';
import {catalogAccess} from '@/lib/staff/access';
import {SiteHeader} from '@/components/discovery/site-header';
import {FinanceAccountEditor} from '@/components/finance/account-editor';
export const dynamic = 'force-dynamic';
export default async function FinanceAccounts({searchParams}: {searchParams: Promise<Record<string, string | string[] | undefined>>}) {
  const {client, user, membership} = await catalogAccess(['admin', 'finance']);
  if (!user) redirect('/sign-in'); if (!membership) notFound();
  const input = await searchParams;
  const page = typeof input.page === 'string' && /^\d{1,5}$/.test(input.page) ? Math.max(1, Number(input.page)) : 1;
  const href = (next: number) => `/staff/finance/accounts?page=${next}`;
  const query = (head = false) => client.from('finance_accounts').select('id,code,name,account_class,approved_by,approval_reason,created_at', {head, count: 'exact'}).eq('organization_id', membership.organization_id);
  const count = await query(true); if (count.error) throw new Error('Unable to count approved finance accounts.');
  const pages = Math.max(1, Math.ceil((count.count || 0)/25)); if (page > pages) redirect(href(pages));
  const rows = await query().order('code').order('id').range((page-1)*25, page*25-1);
  return <><SiteHeader/><main className="account-layout"><section className="account-card"><p className="eyebrow">Finance</p><h1>Approved account register</h1><p>Organization accounts used for journal postings. An account registration does not create a balance or confirm a payment.</p>{membership.role === 'admin' ? <FinanceAccountEditor/> : <p>An organization administrator registers approved accounts. Finance staff can review this register.</p>}{rows.error ? <p role="alert">Unable to load accounts. Please refresh.</p> : rows.data?.length ? rows.data.map(account => <article className="staff-editor" key={account.id}><h2>{account.code} · {account.name}</h2><p>{account.account_class}</p><p>Approval reason: {account.approval_reason}</p><small>Approved by {account.approved_by} · {new Date(account.created_at).toLocaleString('en-JM', {timeZone: 'America/Jamaica'})} (Jamaica time)</small><p>Account reference: {account.id}</p><a href={`/staff/finance/accounts/${account.id}`}>View account statement</a></article>) : <p>No approved accounts registered.</p>}<nav className="results-toolbar" aria-label="Finance account pages">{page > 1 ? <a href={href(page-1)}>← Previous</a> : <span/>}<span>{count.count || 0} accounts · Page {page} of {pages}</span>{page < pages ? <a href={href(page+1)}>Next →</a> : <span/>}</nav><a href="/staff/finance/trial-balance">Trial balance</a> · <a href="/staff/finance/journals">Post an approved journal</a> · <a href="/account">My account</a></section></main></>;
}
