'use client';
import {useRef, useState, type FormEvent} from 'react';
import {useRouter} from 'next/navigation';
import {createClient} from '@/lib/supabase/client';
import {documentFile} from '@/lib/documents/files';
export type EvidenceFile = {id: string; file_name: string; state: string; expires_at: string; frozen: boolean};
export function EvidenceFiles({files, offerId, editable = false, enabled = false}: {files: EvidenceFile[]; offerId?: string; editable?: boolean; enabled?: boolean}) {
  const router = useRouter(), [busy, setBusy] = useState(false), [message, setMessage] = useState('');
  const retry = useRef<{file: File; requestId: string; evidenceId?: string} | null>(null);
  async function call(body: unknown) {
    const response = await fetch('/api/contractor-evidence', {method: 'POST', headers: {'Content-Type': 'application/json'}, body: JSON.stringify(body)});
    const result = await response.json(); if (!response.ok) throw new Error(result.error || 'Evidence action failed.'); return result;
  }
  async function upload(event: FormEvent<HTMLFormElement>) {
    event.preventDefault(); const form = event.currentTarget;
    const file = (form.elements.namedItem('file') as HTMLInputElement).files?.[0]; if (!file) return;
    setBusy(true); setMessage('');
    try {
      documentFile(file.name, file.type, file.size);
      if (retry.current?.file !== file) retry.current = {file, requestId: crypto.randomUUID()};
      const attempt = retry.current;
      if (!attempt.evidenceId) {
        const result = await call({action: 'reserve', offer_id: offerId, request_id: attempt.requestId, file_name: file.name, mime_type: file.type, size: file.size});
        if (result.state !== 'uploaded') {
          const {error} = await createClient().storage.from('contractor-evidence').uploadToSignedUrl(result.path, result.token, file, {contentType: file.type});
          if (error) {router.refresh(); throw new Error('Upload interrupted. Retry the same file, or finish it from the file list if the transfer completed.');}
        }
        attempt.evidenceId = result.id;
      }
      await call({action: 'finish', id: attempt.evidenceId});
      retry.current = null; form.reset(); setMessage('Evidence uploaded. Management still needs to review its contents.'); router.refresh();
    } catch (error) {setMessage(error instanceof Error ? error.message : 'Unable to upload evidence.');} finally {setBusy(false);}
  }
  async function action(id: string, operation: 'download' | 'withdraw' | 'finish') {
    setBusy(true); setMessage('');
    try {
      if (operation === 'download') {
        const response = await fetch(`/api/contractor-evidence?id=${encodeURIComponent(id)}`, {cache: 'no-store'}), result = await response.json();
        if (!response.ok) throw new Error(result.error || 'Download unavailable.'); window.location.assign(result.url);
      } else {await call({action: operation, id}); router.refresh(); setMessage(operation === 'withdraw' ? 'Evidence withdrawn.' : 'File verified and ready for review.');}
    } catch (error) {setMessage(error instanceof Error ? error.message : 'Evidence action failed.');} finally {setBusy(false);}
  }
  return <section><h2>Private evidence files</h2><p>Files receive basic format checks. Management must verify the work and file contents separately. Files included in submitted reports stay fixed.</p>{files.length ? files.map(file => <article className="staff-editor" key={file.id}><h3>{file.file_name}</h3><p>{file.state === 'uploaded' ? 'Format checked · Ready for review' : Date.parse(file.expires_at) <= Date.now() ? 'Reservation expired' : 'Upload not finalized'}{file.frozen ? ' · Included in a submitted report' : ''}</p>{file.state === 'uploaded' && <button disabled={busy} onClick={() => action(file.id, 'download')}>Download evidence</button>}{editable && !file.frozen && file.state === 'reserved' && Date.parse(file.expires_at) > Date.now() && <button disabled={busy || !enabled} onClick={() => action(file.id, 'finish')}>Finish uploaded file</button>}{editable && !file.frozen && <button disabled={busy} onClick={() => action(file.id, 'withdraw')}>Withdraw evidence</button>}</article>) : <p>No evidence files recorded.</p>}{editable && offerId && (enabled ? <form className="staff-editor" onSubmit={upload}><label>PDF, JPEG or PNG up to 8 MB<input name="file" type="file" accept="application/pdf,image/jpeg,image/png" required disabled={busy}/></label><p>Upload only evidence relevant to this work. Up to ten live files per assignment.</p><button className="primary" disabled={busy}>{busy ? 'Working…' : 'Upload private evidence'}</button></form> : <p>Private uploads are being configured. Please contact management.</p>)}<p role="status" aria-live="polite">{message}</p></section>;
}
