'use client';
import {useRef, useState} from 'react';
type Account = {id: string; code: string; name: string; account_class: string};
export function AccountPicker({value, onChange,accountClasses}: {value: string; onChange: (id: string) => void;accountClasses?:readonly string[]}) {
  const [term, setTerm] = useState(''), [field, setField] = useState('code');
  const [accounts, setAccounts] = useState<Account[]>([]), [selected, setSelected] = useState<Account | null>(null);
  const [busy, setBusy] = useState(false), [message, setMessage] = useState('');
  const generation = useRef(0);
  function invalidate() {generation.current++;setAccounts([]);setBusy(false);setMessage('');}
  async function search() {
    const current = ++generation.current;setBusy(true);setMessage('');setAccounts([]);
    try {
      const response = await fetch(`/api/staff/finance-accounts/search?${new URLSearchParams({q:term,field,...accountClasses?.length?{classes:accountClasses.join(',')}:{}})}`, {cache: 'no-store'});
      const result = await response.json();if (generation.current !== current) return;
      if (!response.ok) throw new Error(result.error || 'Unable to search accounts.');
      if(accountClasses?.length&&result.accounts.some((account:Account)=>!accountClasses.includes(account.account_class)))throw new Error('Account results do not match the required classifications. Retry the search.');
      setAccounts(result.accounts);setMessage(result.more ? 'Showing 25 accounts. Refine your search to find others.' : result.accounts.length ? 'Select an approved account.' : 'No approved accounts match.');
    } catch (error) {if (generation.current === current) setMessage(error instanceof Error ? error.message : 'Unable to search accounts.');} finally {if (generation.current === current) setBusy(false);}
  }
  return <section><label>Find approved account<input value={term} maxLength={120} onChange={event => {invalidate();setTerm(event.target.value);}}/></label><label>Search by<select value={field} onChange={event => {invalidate();setField(event.target.value);}}><option value="code">Account code</option><option value="name">Account name</option></select></label><button type="button" disabled={busy} onClick={search}>{busy ? 'Searching…' : 'Search accounts'}</button>{accounts.map(account => <button type="button" key={account.id} onClick={() => {onChange(account.id);setSelected(account);invalidate();}}>{account.code} · {account.name} · {account.account_class}</button>)}<p role="status">{message}</p><p>{value ? `Selected: ${selected?.id === value ? `${selected.code} · ${selected.name}` : value}` : 'Choose an approved account before posting.'}</p>{value && <button type="button" onClick={() => {onChange('');setSelected(null);invalidate();}}>Clear account</button>}</section>;
}
