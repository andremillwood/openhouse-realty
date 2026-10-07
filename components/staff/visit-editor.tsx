'use client';
import {useRef, useState, type FormEvent} from 'react';
import {jamaicaTimestamp} from '@/lib/staff/jamaica-time';
export function VisitEditor({action, offerId, offerVersion, visitId, version, returnTo}: {action: 'propose'|'confirm'|'decline'|'cancel'; offerId?: string; offerVersion?: number; visitId?: string; version?: number; returnTo: string}) {
  const [busy, setBusy] = useState(false), [message, setMessage] = useState('');
  const retry = useRef<{payload: string; id: string}|null>(null);
  const label = {propose: 'Propose a visit', confirm: 'Confirm this window', decline: 'Decline this window', cancel: 'Cancel this visit'}[action];
  async function submit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault(); setBusy(true); setMessage('');
    try {
      const form = new FormData(event.currentTarget);
      const input = action === 'propose' ? {action, visit_id: null, version: 0, offer_id: offerId, offer_version: offerVersion, starts_at: jamaicaTimestamp(String(form.get('starts_at'))), ends_at: jamaicaTimestamp(String(form.get('ends_at'))), shared_note: String(form.get('shared_note') || ''), reason: String(form.get('reason') || ''), approved: form.get('approved') === 'on'} : {action, visit_id: visitId, version, reason: String(form.get('reason') || '')};
      const payload = JSON.stringify(input); if (retry.current?.payload !== payload) retry.current = {payload, id: crypto.randomUUID()};
      const response = await fetch('/api/contractor-visits', {method: 'POST', headers: {'Content-Type': 'application/json'}, body: JSON.stringify({...input, request_id: retry.current.id})});
      const result = await response.json(); if (!response.ok) {if (response.status < 500) retry.current = null; throw new Error(result.error || 'Unable to update this visit.');}
      window.location.assign(returnTo);
    } catch (error) {setMessage(error instanceof Error ? error.message : 'Unable to update this visit. Please retry.');} finally {setBusy(false);}
  }
  return <form className="staff-editor" onSubmit={submit}><h2>{label}</h2>{action === 'propose' && <><p>Enter Jamaica time (UTC−5). Choose a future window within 90 days, lasting up to eight hours.</p><label>Starts at (Jamaica time)<input type="datetime-local" name="starts_at" required/></label><label>Ends at (Jamaica time)<input type="datetime-local" name="ends_at" required/></label><label>Shared appointment note<textarea name="shared_note" required minLength={5} maxLength={1000}/></label><label><input type="checkbox" name="approved" required/> I approve this window and note for sharing with the contractor.</label></>}<label>Decision reason<textarea name="reason" required minLength={5} maxLength={500}/></label>{action !== 'propose' && <label><input type="checkbox" required/> I have reviewed the visit window and confirm this response.</label>}<button className="primary" disabled={busy}>{busy ? 'Saving…' : label}</button><p role="status">{message}</p></form>;
}
