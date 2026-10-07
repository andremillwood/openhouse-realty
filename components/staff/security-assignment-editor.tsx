'use client';
import {useRef, useState, type FormEvent} from 'react';
export function SecurityAssignmentEditor({propertyId, assignment}: {propertyId?: string; assignment?: {id: string; user_id: string; is_active: boolean; version: number}}) {
  const [busy, setBusy] = useState(false), [message, setMessage] = useState('');
  const retry = useRef<{payload: string; id: string}|null>(null);
  async function submit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault(); setBusy(true); setMessage(''); const form = new FormData(event.currentTarget);
    const input = {assignment_id: assignment?.id || null, version: assignment?.version || 0, property_id: assignment ? null : propertyId, email: assignment ? null : String(form.get('email') || ''), is_active: assignment ? form.get('is_active') === 'on' : true, reason: String(form.get('reason') || ''), approved: form.get('approved') === 'on'};
    const payload = JSON.stringify(input); if (retry.current?.payload !== payload) retry.current = {payload, id: crypto.randomUUID()};
    try {
      const response = await fetch('/api/staff/security-assignments', {method: 'POST', headers: {'Content-Type': 'application/json'}, body: JSON.stringify({...input, request_id: retry.current.id})});
      const result = await response.json(); if (!response.ok) {if (response.status < 500) retry.current = null; throw new Error(result.error || 'Unable to save security assignment.');}
      window.location.assign(`/staff/security/assignments/${result.id}`);
    } catch (error) {setMessage(error instanceof Error ? error.message : 'Unable to save. Please retry.');} finally {setBusy(false);}
  }
  return <form className="staff-editor" onSubmit={submit}><h2>{assignment ? 'Review security assignment' : 'Approve security coverage'}</h2>{assignment ? <><p>Account reference: {assignment.user_id} · Revision {assignment.version}. Property and account are fixed.</p><label><input type="checkbox" name="is_active" defaultChecked={assignment.is_active}/> Active assignment</label></> : <label>Approved verified account email<input type="email" name="email" required maxLength={254}/></label>}<label>Approval / change reason<textarea name="reason" required minLength={5} maxLength={500}/></label><label><input type="checkbox" name="approved" required/> Open House approved this property security assignment or change.</label><button className="primary" disabled={busy}>{busy ? 'Saving…' : 'Save assignment'}</button><p role="status">{message}</p></form>;
}
