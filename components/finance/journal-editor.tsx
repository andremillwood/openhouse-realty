'use client';
import {useRef, useState, type FormEvent} from 'react';
import {DimensionPicker} from '@/components/finance/dimension-picker';
import {AccountPicker} from '@/components/finance/account-picker';
import {journalInput} from '@/lib/finance/journal-validation';
import {jmdMinor, formatJmdMinor} from '@/lib/finance/money';
type DraftLine = {key: number; account: string; side: 'debit' | 'credit'; amount: string; property: string; unit: string};
const fresh = (key: number, side: 'debit' | 'credit' = 'debit'): DraftLine => ({key, account: '', side, amount: '', property: '', unit: ''});
export function JournalEditor() {
  const [lines, setLines] = useState<DraftLine[]>([fresh(0), fresh(1, 'credit')]);
  const sequence = useRef(2), retry = useRef<{payload: string; id: string} | null>(null);
  const [busy, setBusy] = useState(false), [message, setMessage] = useState('');
  function change(key: number, patch: Partial<DraftLine>) {setLines(previous => previous.map(line => line.key === key ? {...line, ...patch} : line));}
  let totals = 'Enter amounts to compare totals.';
  try {let debit = 0n, credit = 0n;for (const line of lines) {const amount = BigInt(jmdMinor(line.amount));if (line.side === 'debit') debit += amount;else credit += amount;}totals = `Debits ${formatJmdMinor(debit)} · Credits ${formatJmdMinor(credit)} · ${debit === credit && debit > 0n ? 'Balanced' : 'Not balanced'}`;} catch {}
  async function submit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();if (busy) return;setBusy(true);setMessage('');
    try {
      const element = event.currentTarget;
      const form = new FormData(element);
      const draft = {currency: 'JMD', memo: String(form.get('memo') || ''), reason: String(form.get('reason') || ''), approved: form.get('approved') === 'on', lines: lines.map(line => ({account_id: line.account.trim(), property_id: line.property.trim() || null, unit_id: line.unit.trim() || null, debit_minor: line.side === 'debit' ? jmdMinor(line.amount) : 0, credit_minor: line.side === 'credit' ? jmdMinor(line.amount) : 0}))};
      const payload = JSON.stringify(draft);
      if (retry.current?.payload !== payload) retry.current = {payload, id: crypto.randomUUID()};
      const input = journalInput({...draft, request_id: retry.current.id});
      const response = await fetch('/api/staff/finance-journals', {method: 'POST', headers: {'Content-Type': 'application/json'}, body: JSON.stringify(input)});
      const result = await response.json();
      if (!response.ok) {if (response.status < 500) retry.current = null;throw new Error(result.error || 'Unable to post journal.');}
      setMessage(`Journal posted. Reference: ${result.id}`);retry.current = null;
      window.location.assign(`/staff/finance/journals/${result.id}`);
      setLines([fresh(sequence.current++), fresh(sequence.current++, 'credit')]);element.reset();
    } catch (error) {setMessage(error instanceof Error ? error.message : 'Posting unavailable. Retry the same submission.');} finally {setBusy(false);}
  }
  return <form className="staff-editor" onSubmit={submit}><h2>Post an approved journal</h2><p>Find approved accounts by code or name, or review the <a href="/staff/finance/accounts">account register</a>. Enter JMD amounts without commas. A journal records an accounting decision; verify supporting records before approval.</p><fieldset disabled={busy}><label>Posting description<textarea name="memo" minLength={5} maxLength={1000} required/></label>{lines.map((line, index) => <fieldset key={line.key}><legend>Line {index+1}</legend><AccountPicker value={line.account} onChange={account => change(line.key, {account})}/><label>Entry type<select value={line.side} onChange={event => change(line.key, {side: event.target.value as 'debit' | 'credit'})}><option value="debit">Debit</option><option value="credit">Credit</option></select></label><label>Amount (JMD)<input inputMode="decimal" value={line.amount} onChange={event => change(line.key, {amount: event.target.value})} maxLength={15} required/></label><DimensionPicker kind="property" value={line.property} onChange={property => change(line.key, {property, unit: ''})}/><DimensionPicker key={line.property} kind="unit" propertyId={line.property} value={line.unit} onChange={unit => change(line.key, {unit})}/><button type="button" disabled={lines.length <= 2} onClick={() => setLines(previous => previous.filter(value => value.key !== line.key))}>Remove line {index+1}</button></fieldset>)}<button type="button" disabled={lines.length >= 200} onClick={() => {const next = fresh(sequence.current++);setLines(previous => [...previous, next]);}}>Add line</button><p aria-live="polite">{totals}</p><label>Approval reason<textarea name="reason" minLength={5} maxLength={500} required/></label><label><input type="checkbox" name="approved" required/> I approve this balanced journal and its supporting records.</label><button className="primary">{busy ? 'Posting…' : 'Post journal'}</button></fieldset><p role="status">{message}</p></form>;
}
