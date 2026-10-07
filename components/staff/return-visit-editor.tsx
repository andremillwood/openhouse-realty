'use client';
import {useRef, useState, type FormEvent} from 'react';
type Props = {reportId: string; reportVersion: number; offerVersion: number; workVersion: number; returnTo: string};
export function ReturnVisitEditor(props: Props) {
  const [busy, setBusy] = useState(false), [message, setMessage] = useState('');
  const retry = useRef<{payload: string; id: string} | null>(null);
  async function submit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault(); setBusy(true); setMessage('');
    const form = new FormData(event.currentTarget);
    const input = {report_id: props.reportId, report_version: props.reportVersion, offer_version: props.offerVersion, work_version: props.workVersion, reason: String(form.get('reason') || ''), approved: form.get('approved') === 'on'};
    const payload = JSON.stringify(input);
    if (retry.current?.payload !== payload) retry.current = {payload, id: crypto.randomUUID()};
    try {
      const response = await fetch('/api/contractor-return-visits', {method: 'POST', headers: {'Content-Type': 'application/json'}, body: JSON.stringify({...input, request_id: retry.current.id})});
      const result = await response.json();
      if (!response.ok) {if (response.status < 500) retry.current = null; throw new Error(result.error || 'Unable to approve return visit.');}
      window.location.assign(props.returnTo);
    } catch (error) {setMessage(error instanceof Error ? error.message : 'Unable to save. Please retry.');} finally {setBusy(false);}
  }
  return <form className="staff-editor" onSubmit={submit}><h2>Arrange a correction visit</h2><p>Use this when the shared review requires more work on site. The previous visit closes and its entry authorization is revoked. You will then propose a new appointment for the contractor to confirm. The report and attendance records remain available.</p><p>For documentation-only corrections, the contractor can submit a revised report without another visit.</p><label>Internal decision reason<textarea name="reason" minLength={5} maxLength={500} required/></label><label><input type="checkbox" name="approved" required/> I independently approve a return visit for the corrections described in the shared review.</label><button className="primary" disabled={busy}>{busy ? 'Saving…' : 'Approve return visit and continue to scheduling'}</button><p role="status">{message}</p></form>;
}
