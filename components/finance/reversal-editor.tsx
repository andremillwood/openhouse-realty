'use client';
import {useRef, useState, type FormEvent} from 'react';
export function ReversalEditor({journalId}: {journalId: string}) {
  const [busy, setBusy] = useState(false), [message, setMessage] = useState('');
  const retry = useRef<{payload: string; id: string} | null>(null);
  async function submit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();if (busy) return;setBusy(true);setMessage('');
    const form = new FormData(event.currentTarget);
    const input = {journal_id: journalId, reason: String(form.get('reason') || '').trim(), approved: form.get('approved') === 'on'};
    const payload = JSON.stringify(input);
    if (retry.current?.payload !== payload) retry.current = {payload, id: crypto.randomUUID()};
    try {
      const response = await fetch('/api/staff/finance-reversals', {method: 'POST', headers: {'Content-Type': 'application/json'}, body: JSON.stringify({...input, request_id: retry.current.id})});
      const result = await response.json();
      if (!response.ok) {if (response.status < 500) retry.current = null;throw new Error(result.error || 'Unable to reverse journal.');}
      window.location.assign(`/staff/finance/journals/${result.id}`);
    } catch (error) {setMessage(error instanceof Error ? error.message : 'Reversal unavailable. Retry the same submission.');} finally {setBusy(false);}
  }
  return <form className="staff-editor" onSubmit={submit}><h2>Approve a reversal</h2><p>This posts a separate journal with opposite amounts and preserves the original. Review supporting records before approving.</p><fieldset disabled={busy}><label>Reversal reason<textarea name="reason" minLength={5} maxLength={500} required/></label><label><input type="checkbox" name="approved" required/> I approve a full reversal of this journal.</label><button className="primary">{busy ? 'Reversing…' : 'Post approved reversal'}</button></fieldset><p role="status">{message}</p></form>;
}
