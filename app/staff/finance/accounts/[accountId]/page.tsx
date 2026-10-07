import {notFound, redirect} from 'next/navigation';
import {catalogAccess} from '@/lib/staff/access';
import {SiteHeader} from '@/components/discovery/site-header';
import {statementQuery} from '@/lib/finance/statement-query';
import {formatJmdMinor} from '@/lib/finance/money';
export const dynamic = 'force-dynamic';
type Statement = {account: {id: string; code: string; name: string; class: string};from: string;to: string;opening_minor: string;debit_minor: string;credit_minor: string;closing_minor: string;page: number;pages: number;total: number;as_of: string;entries: {line_id: string;journal_id: string;posted_at: string;memo: string;debit_minor: string;credit_minor: string;balance_minor: string}[]};
export default async function AccountStatement({params, searchParams}: {params: Promise<{accountId: string}>;searchParams: Promise<Record<string, string | string[] | undefined>>}) {
  const {client, user, membership} = await catalogAccess(['admin', 'finance']);
  if (!user) redirect('/sign-in');if (!membership) notFound();
  const {accountId} = await params;
  if (!/^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(accountId)) notFound();
  const today = new Intl.DateTimeFormat('en-CA', {timeZone: 'America/Jamaica', year: 'numeric', month: '2-digit', day: '2-digit'}).format(new Date());
  let query;try {query = statementQuery(await searchParams, today);} catch {return <><SiteHeader/><main className="account-layout"><section className="account-card"><h1>Account statement</h1><p role="alert">Choose valid dates spanning up to 367 inclusive days.</p><a href={`/staff/finance/accounts/${accountId}`}>Reset date filters</a></section></main></>;}
  const {data, error} = await client.rpc('finance_account_statement', {p_account_id: accountId, p_from: query.from, p_to: query.to, p_page: query.page});
  if (error?.code === '42501') notFound();if (error || !data) throw new Error('Unable to load account statement.');
  const statement = data as Statement;
  const href = (page: number) => `/staff/finance/accounts/${accountId}?${new URLSearchParams({from: query.from, to: query.to, page: String(page)})}`;
  if (statement.page !== query.page) redirect(href(statement.page));
  return <><SiteHeader/><main className="account-layout"><section className="account-card"><p className="eyebrow">Finance · Account statement</p><h1>{statement.account.code} · {statement.account.name}</h1><p>Balances use debits minus credits. Negative balances show a net credit. Period dates use Jamaica time.</p><form><label>From<input type="date" name="from" defaultValue={query.from} required/></label><label>Through<input type="date" name="to" defaultValue={query.to} required/></label><button>View statement</button></form><dl><dt>Opening balance</dt><dd>{formatJmdMinor(statement.opening_minor)}</dd><dt>Period debits</dt><dd>{formatJmdMinor(statement.debit_minor)}</dd><dt>Period credits</dt><dd>{formatJmdMinor(statement.credit_minor)}</dd><dt>Closing balance</dt><dd>{formatJmdMinor(statement.closing_minor)}</dd></dl><p>Statement as of {new Date(statement.as_of).toLocaleString('en-JM', {timeZone: 'America/Jamaica'})} (Jamaica time)</p>{statement.entries.length ? statement.entries.map(line => <article className="staff-editor" key={line.line_id}><h2>{line.memo}</h2><p>{new Date(line.posted_at).toLocaleString('en-JM', {timeZone: 'America/Jamaica'})}</p><p>Debit {formatJmdMinor(line.debit_minor)} · Credit {formatJmdMinor(line.credit_minor)} · Balance {formatJmdMinor(line.balance_minor)}</p><a href={`/staff/finance/journals/${line.journal_id}`}>Review journal</a></article>) : <p>No postings in this period.</p>}<nav aria-label="Statement pages">{statement.page>1 && <a href={href(statement.page-1)}>Previous</a>}<span> · {statement.total} lines · Page {statement.page} of {statement.pages} · </span>{statement.page<statement.pages && <a href={href(statement.page+1)}>Next</a>}</nav><a href="/staff/finance/accounts">Account register</a></section></main></>;
}
