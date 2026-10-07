'use client';
import {useRef, useState, type FormEvent} from 'react';
import {jamaicaTimestamp} from '@/lib/staff/jamaica-time';
export function EntryPermitEditor({action, visit, permitId, version, returnTo}: {action: 'authorize'|'revoke'; visit?: {id: string; version: number; starts_at: string; ends_at: string}; permitId?: string; version?: number; returnTo: string}) {
  const local = (value: string) => new Date(Date.parse(value)-5*60*60*1000).toISOString().slice(0,16);
  const [busy, setBusy] = useState(false), [message, setMessage] = useState('');
  const retry = useRef<{payload: string; id: string}|null>(null);
  const label = {authorize: 'Authorize entry', revoke: 'Revoke entry'}[action];
  async function submit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault(); setBusy(true); setMessage('');
    try {
      const form = new FormData(event.currentTarget);
      const input = action === 'authorize' ? {action, permit_id: null, version: 0, visit_id: visit?.id, visit_version: visit?.version, valid_from: jamaicaTimestamp(String(form.get('valid_from'))), valid_until: jamaicaTimestamp(String(form.get('valid_until'))), shared_instructions: String(form.get('shared_instructions') || ''), reason: String(form.get('reason') || ''), approved: form.get('approved') === 'on'} : {action, permit_id: permitId, version, reason: String(form.get('reason') || '')};
      const payload = JSON.stringify(input); if (retry.current?.payload !== payload) retry.current = {payload, id: crypto.randomUUID()};
      const response = await fetch('/api/staff/entry-permits', {method: 'POST', headers: {'Content-Type': 'application/json'}, body: JSON.stringify({...input, request_id: retry.current.id})});
      const result = await response.json(); if (!response.ok) {if (response.status < 500) retry.current = null; throw new Error(result.error || 'Unable to update entry authorization.');}
      window.location.assign(returnTo);
    } catch (error) {setMessage(error instanceof Error ? error.message : 'Unable to update entry authorization. Please retry.');} finally {setBusy(false);}
  }
  return <form className="staff-editor" onSubmit={submit}><h2>{label}</h2>{action === 'authorize' && <><p>Enter Jamaica time (UTC−5). The access window must fit within the confirmed appointment.</p><label>Starts at (Jamaica time)<input type="datetime-local" name="valid_from" required defaultValue={visit ? local(visit.starts_at) : undefined} min={visit ? local(visit.starts_at) : undefined} max={visit ? local(visit.ends_at) : undefined}/></label><label>Ends at (Jamaica time)<input type="datetime-local" name="valid_until" required defaultValue={visit ? local(visit.ends_at) : undefined} min={visit ? local(visit.starts_at) : undefined} max={visit ? local(visit.ends_at) : undefined}/></label><label>Shared access instructions<textarea name="shared_instructions" required minLength={5} maxLength={1000}/></label><label><input type="checkbox" name="approved" required/> I have authority to arrange access and approve these instructions and this window.</label></>}<label>Authority / decision reason<textarea name="reason" required minLength={10} maxLength={500}/></label>{action !== 'authorize' && <label><input type="checkbox" required/> I have reviewed the authorization and confirm this response.</label>}<button className="primary" disabled={busy}>{busy ? 'Saving…' : label}</button><p role="status">{message}</p></form>;
}
