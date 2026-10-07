'use client';
import {useRef, useState, type FormEvent} from 'react';
export function PresenceEditor({permitId, presenceId, version = 0}: {permitId: string; presenceId?: string; version?: number}) {
  const [busy, setBusy] = useState(false), [message, setMessage] = useState('');
  const retry = useRef<{payload: string; id: string} | null>(null);
  async function submit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault(); setBusy(true); setMessage('');
    const form = new FormData(event.currentTarget);
    const input = {action: presenceId ? 'check_out' : 'check_in', permit_id: presenceId ? null : permitId, presence_id: presenceId || null, version, identity_checked: presenceId ? null : form.get('identity_checked') === 'on', reason: String(form.get('reason') || '')};
    const payload = JSON.stringify(input);
    if (retry.current?.payload !== payload) retry.current = {payload, id: crypto.randomUUID()};
    try {
      const response = await fetch('/api/security/presence', {method: 'POST', headers: {'Content-Type': 'application/json'}, body: JSON.stringify({...input, request_id: retry.current.id})});
      const result = await response.json();
      if (!response.ok) {if (response.status < 500) retry.current = null; throw new Error(result.error || 'Unable to record presence.');}
      window.location.assign(`/security/entry/${permitId}`);
    } catch (error) {setMessage(error instanceof Error ? error.message : 'Unable to record presence. Please retry.');} finally {setBusy(false);}
  }
  return <form className="staff-editor" onSubmit={submit}><h2>{presenceId ? 'Record departure' : 'Record arrival'}</h2>{!presenceId && <label><input type="checkbox" name="identity_checked" required/> I checked the visitor’s identity against the approved contractor and permit.</label>}<label>{presenceId ? 'Departure note' : 'Arrival note'}<textarea name="reason" minLength={5} maxLength={500} required/></label><button className="primary" disabled={busy}>{busy ? 'Recording…' : presenceId ? 'Confirm departure' : 'Confirm arrival'}</button><p role="status">{message}</p></form>;
}
