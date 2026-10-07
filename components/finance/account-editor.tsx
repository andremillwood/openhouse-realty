'use client';
import {useRef, useState, type FormEvent} from 'react';
import {financeAccountClasses} from '@/lib/finance/account-validation';
export function FinanceAccountEditor() {
  const [busy, setBusy] = useState(false), [message, setMessage] = useState('');
  const retry = useRef<{payload: string; id: string} | null>(null);
  async function submit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault(); setBusy(true); setMessage('');
    const form = new FormData(event.currentTarget);
    const input = {code: String(form.get('code') || ''), name: String(form.get('name') || ''), account_class: String(form.get('account_class') || ''), reason: String(form.get('reason') || ''), approved: form.get('approved') === 'on'};
    const payload = JSON.stringify(input);
    if (retry.current?.payload !== payload) retry.current = {payload, id: crypto.randomUUID()};
    try {
      const response = await fetch('/api/staff/finance-accounts', {method: 'POST', headers: {'Content-Type': 'application/json'}, body: JSON.stringify({...input, request_id: retry.current.id})});
      const result = await response.json();
      if (!response.ok) {if (response.status < 500) retry.current = null; throw new Error(result.error || 'Unable to register approved account.');}
      window.location.assign('/staff/finance/accounts');
    } catch (error) {setMessage(error instanceof Error ? error.message : 'Unable to save. Please retry.');} finally {setBusy(false);}
  }
  return <form className="staff-editor" onSubmit={submit}><h2>Register an approved account</h2><p>Use the account code, name and classification approved for your organization’s chart. Registered accounts are fixed records.</p><label>Account code<input name="code" minLength={1} maxLength={40} required/></label><label>Account name<input name="name" minLength={2} maxLength={120} required/></label><label>Classification<select name="account_class" defaultValue="" required><option value="" disabled>Choose approved classification</option>{financeAccountClasses.map(value => <option key={value} value={value}>{value}</option>)}</select></label><label>Approval reason<textarea name="reason" minLength={5} maxLength={500} required/></label><label><input type="checkbox" name="approved" required/> I approve this account for the organization’s chart.</label><button className="primary" disabled={busy}>{busy ? 'Saving…' : 'Register approved account'}</button><p role="status">{message}</p></form>;
}
