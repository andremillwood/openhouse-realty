import {notFound, redirect} from 'next/navigation';
import {catalogAccess} from '@/lib/staff/access';
import {SiteHeader} from '@/components/discovery/site-header';
import {statementQuery} from '@/lib/finance/statement-query';
import {formatJmdMinor} from '@/lib/finance/money';
export const dynamic = 'force-dynamic';
type Trial = {through: string;debit_minor: string;credit_minor: string;balanced: boolean;page: number;pages: number;total: number;as_of: string;accounts: {id: string;code: string;name: string;class: string;debit_minor: string;credit_minor: string}[]};
export default async function TrialBalance({searchParams}: {searchParams: Promise<Record<string, string | string[] | undefined>>}) {
  const {client, user, membership} = await catalogAccess(['admin', 'finance']);
  if (!user) redirect('/sign-in');if (!membership) notFound();
  const today = new Intl.DateTimeFormat('en-CA', {timeZone: 'America/Jamaica', year: 'numeric', month: '2-digit', day: '2-digit'}).format(new Date());
  const input = await searchParams;const through = input.through === undefined ? today : input.through;
  let query;try {query = statementQuery({from: through, to: through, page: input.page}, today);} catch {return <><SiteHeader/><main className="account-layout"><section className="account-card"><h1>Trial balance</h1><p role="alert">Choose a valid through date.</p><a href="/staff/finance/trial-balance">Reset date filter</a></section></main></>;}
  const {data, error} = await client.rpc('finance_trial_balance', {p_through: query.to, p_page: query.page});
  if (error?.code === '42501') notFound();if (error || !data) throw new Error('Unable to load trial balance.');
  const trial = data as Trial;
  const href = (page: number) => `/staff/finance/trial-balance?${new URLSearchParams({through: query.to, page: String(page)})}`;
  if (trial.page !== query.page) redirect(href(trial.page));
  return <><SiteHeader/><main className="account-layout"><section className="account-card"><p className="eyebrow">Finance</p><h1>Trial balance</h1><p>Net account balances from all journals posted through the selected Jamaica calendar date. Reversals remain in the journal history.</p><form><label>Through<input type="date" name="through" defaultValue={query.to} required/></label><button>View trial balance</button></form><dl><dt>Total debit balances</dt><dd>{formatJmdMinor(trial.debit_minor)}</dd><dt>Total credit balances</dt><dd>{formatJmdMinor(trial.credit_minor)}</dd></dl><p role={trial.balanced ? 'status' : 'alert'}>{trial.balanced ? 'Debit and credit balances agree.' : 'Balances differ. Investigate the underlying journals.'}</p><p>As of {new Date(trial.as_of).toLocaleString('en-JM', {timeZone: 'America/Jamaica'})} (Jamaica time)</p>{trial.accounts.length ? trial.accounts.map(account => <article className="staff-editor" key={account.id}><h2>{account.code} · {account.name}</h2><p>{account.class}</p><p>Debit balance {formatJmdMinor(account.debit_minor)} · Credit balance {formatJmdMinor(account.credit_minor)}</p><a href={`/staff/finance/accounts/${account.id}?${new URLSearchParams({from: `${query.to.slice(0,7)}-01`, to: query.to})}`}>Trace account statement</a></article>) : <p>No approved accounts registered.</p>}<nav aria-label="Trial balance pages">{trial.page>1 && <a href={href(trial.page-1)}>Previous</a>}<span> · {trial.total} accounts · Page {trial.page} of {trial.pages} · </span>{trial.page<trial.pages && <a href={href(trial.page+1)}>Next</a>}</nav><a href="/staff/finance/accounts">Account register</a> · <a href="/staff/finance/journals">Journal history</a></section></main></>;
}
