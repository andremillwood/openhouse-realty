'use client';
import {useRef, useState, type FormEvent} from 'react';
export function WorkOfferEditor({workOrderId, workVersion, contractor}: {workOrderId: string; workVersion: number; contractor: {id: string; company_name: string; trade_coverage: string[]}}) {
  const [busy, setBusy] = useState(false), [message, setMessage] = useState('');
  const retry = useRef<{payload: string; id: string}|null>(null);
  async function submit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault(); setBusy(true); setMessage('');
    const form = new FormData(event.currentTarget);
    const input = {action: 'offer', offer_id: null, version: 0, work_order_id: workOrderId, work_version: workVersion, contractor_id: contractor.id, job_title: String(form.get('job_title') || ''), scope_summary: String(form.get('scope_summary') || ''), trade: String(form.get('trade') || ''), reason: String(form.get('reason') || ''), approved: form.get('approved') === 'on'};
    const payload = JSON.stringify(input); if (retry.current?.payload !== payload) retry.current = {payload, id: crypto.randomUUID()};
    try {
      const response = await fetch('/api/work-offers', {method: 'POST', headers: {'Content-Type': 'application/json'}, body: JSON.stringify({...input, request_id: retry.current.id})});
      const result = await response.json();
      if (!response.ok) {if (response.status < 500) retry.current = null; throw new Error(result.error || 'Unable to create the offer.');}
      window.location.assign(`/staff/work-orders/${workOrderId}/offers`);
    } catch (error) {setMessage(error instanceof Error ? error.message : 'Unable to create the offer. Please retry.');} finally {setBusy(false);}
  }
  return <form className="staff-editor" onSubmit={submit}><h2>Offer work to {contractor.company_name}</h2><p>Write the scope you approve sharing. Internal issue notes are not copied into this offer.</p><label>Shared job title<input name="job_title" required minLength={3} maxLength={160}/></label><label>Approved work scope<textarea name="scope_summary" required minLength={20} maxLength={3000}/></label><label>Approved trade<select name="trade" required>{contractor.trade_coverage.map(trade => <option key={trade} value={trade}>{trade}</option>)}</select></label><label>Internal decision reason<textarea name="reason" required minLength={5} maxLength={500}/></label><label><input name="approved" type="checkbox" required/> I approve this scope for sharing with the selected contractor.</label><button className="primary" disabled={busy}>{busy ? 'Saving…' : 'Create seven-day offer'}</button><p role="status">{message}</p></form>;
}
