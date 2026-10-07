'use client';
import {useRef, useState, type FormEvent} from 'react';

export function WorkOfferResponse({offerId, version, action, returnTo}: {offerId: string; version: number; action: 'accept'|'decline'|'release'|'withdraw'; returnTo: string}) {
  const [busy, setBusy] = useState(false), [message, setMessage] = useState('');
  const retry = useRef<{payload: string; id: string}|null>(null);
  const label = {accept: 'Accept this work', decline: 'Decline this offer', release: 'Release accepted work', withdraw: 'Withdraw this offer'}[action];
  async function submit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault(); setBusy(true); setMessage('');
    const input = {action, offer_id: offerId, version, reason: String(new FormData(event.currentTarget).get('reason') || '')};
    const payload = JSON.stringify(input);
    if (retry.current?.payload !== payload) retry.current = {payload, id: crypto.randomUUID()};
    try {
      const response = await fetch('/api/work-offers', {method: 'POST', headers: {'Content-Type': 'application/json'}, body: JSON.stringify({...input, request_id: retry.current.id})});
      const result = await response.json();
      if (!response.ok) {if (response.status < 500) retry.current = null; throw new Error(result.error || 'Unable to update this offer.');}
      window.location.assign(returnTo);
    } catch (error) {setMessage(error instanceof Error ? error.message : 'Unable to update this offer. Please retry.');}
    finally {setBusy(false);}
  }
  return <form className="staff-editor" onSubmit={submit}><h2>{label}</h2><label>Response reason<textarea name="reason" required minLength={5} maxLength={500}/></label><label><input type="checkbox" required/> I have reviewed the approved scope and confirm this response.</label><button className={action === 'accept' ? 'primary' : 'secondary'} disabled={busy}>{busy ? 'Saving…' : label}</button><p role="status">{message}</p></form>;
}
