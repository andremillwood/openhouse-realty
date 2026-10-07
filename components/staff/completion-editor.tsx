'use client';
import {useRef, useState, type FormEvent} from 'react';
type Props = {returnTo: string} & ({action: 'submit'; offerId: string; offerVersion: number} | {action: 'request_changes' | 'approve'; reportId: string; version: number});
export function CompletionEditor(props: Props) {
  const [busy, setBusy] = useState(false), [message, setMessage] = useState('');
  const retry = useRef<{payload: string; id: string} | null>(null);
  async function submit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault(); setBusy(true); setMessage('');
    const form = new FormData(event.currentTarget), reason = String(form.get('reason') || '');
    const input = props.action === 'submit' ? {action: props.action, offer_id: props.offerId, offer_version: props.offerVersion, version: 0, summary: String(form.get('summary') || ''), tests_performed: String(form.get('tests_performed') || ''), outstanding_items: String(form.get('outstanding_items') || ''), reason} : {action: props.action, report_id: props.reportId, version: props.version, review_message: String(form.get('review_message') || ''), evidence_reviewed: props.action === 'approve' ? form.get('evidence_reviewed') === 'on' : null, reason};
    const payload = JSON.stringify(input);
    if (retry.current?.payload !== payload) retry.current = {payload, id: crypto.randomUUID()};
    try {
      const response = await fetch('/api/completion-reports', {method: 'POST', headers: {'Content-Type': 'application/json'}, body: JSON.stringify({...input, request_id: retry.current.id})});
      const result = await response.json();
      if (!response.ok) {if (response.status < 500) retry.current = null; throw new Error(result.error || 'Unable to save completion report.');}
      window.location.assign(props.returnTo);
    } catch (error) {setMessage(error instanceof Error ? error.message : 'Unable to save. Please retry.');} finally {setBusy(false);}
  }
  const label = props.action === 'submit' ? 'Submit completion report' : props.action === 'approve' ? 'Approve completed work' : 'Request changes';
  return <form className="staff-editor" onSubmit={submit}><h2>{label}</h2>{props.action === 'submit' ? <><p>Record the work and tests accurately. Your submitted report is kept as a fixed record; management reviews it separately.</p><label>Work performed<textarea name="summary" minLength={20} maxLength={4000} required/></label><label>Tests and results<textarea name="tests_performed" minLength={10} maxLength={2000} required/></label><label>Outstanding items or defects<textarea name="outstanding_items" minLength={5} maxLength={2000} required/></label></> : <><label>Review message shared with the contractor<textarea name="review_message" minLength={10} maxLength={2000} required/></label>{props.action === 'approve' && <label><input type="checkbox" name="evidence_reviewed" required/> I independently reviewed the work and evidence and approve completion.</label>}</>}<label>{props.action === 'submit' ? 'Submission note' : 'Internal decision reason'}<textarea name="reason" minLength={5} maxLength={500} required/></label><button className="primary" disabled={busy}>{busy ? 'Saving…' : label}</button><p role="status">{message}</p></form>;
}
