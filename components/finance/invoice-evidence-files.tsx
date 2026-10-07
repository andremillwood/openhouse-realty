'use client';
import {useRef,useState,type FormEvent} from 'react';
import {useRouter} from 'next/navigation';
import {createClient} from '@/lib/supabase/client';
import {documentFile} from '@/lib/documents/files';
import {INVOICE_EVIDENCE_BUCKET} from '@/lib/finance/invoice-evidence';
export type InvoiceEvidenceFile={id:string;kind:string;file_name:string;state:string;expires_at:string};
export function InvoiceEvidenceFiles({files,invoiceId,editable=false,enabled=false,reviewedVersion}:{files:InvoiceEvidenceFile[];invoiceId:string;editable?:boolean;enabled?:boolean;reviewedVersion?:number}){
 const router=useRouter(),[busy,setBusy]=useState(false),[message,setMessage]=useState(''),working=useRef(false);
 const retry=useRef<{file:File;kind:string;requestId:string;evidenceId?:string;transferred?:boolean}|null>(null);
 async function call(body:unknown){
  const response=await fetch('/api/staff/invoice-evidence',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify(body),cache:'no-store'});
  const result=await response.json();if(!response.ok)throw new Error(result.error||'Invoice evidence action failed.');return result;
 }
 async function upload(event:FormEvent<HTMLFormElement>){
  event.preventDefault();if(working.current||!editable||!enabled)return;
  const form=event.currentTarget,file=(form.elements.namedItem('file') as HTMLInputElement).files?.[0],kind=(form.elements.namedItem('kind') as HTMLSelectElement).value;
  if(!file)return;working.current=true;setBusy(true);setMessage('');
  try{
   documentFile(file.name,file.type,file.size);if(!['invoice','supporting'].includes(kind))throw new Error('Choose invoice or supporting evidence.');
   if(retry.current?.file!==file||retry.current.kind!==kind)retry.current={file,kind,requestId:crypto.randomUUID()};
   const attempt=retry.current;
   if(!attempt.transferred){
    const result=await call({action:'reserve',invoice_id:invoiceId,request_id:attempt.requestId,kind,file_name:file.name,mime_type:file.type,size:file.size});
    attempt.evidenceId=result.id;
    if(result.state==='uploaded')attempt.transferred=true;
    else{
     const {error}=await createClient().storage.from(INVOICE_EVIDENCE_BUCKET).uploadToSignedUrl(result.path,result.token,file,{contentType:file.type});
     attempt.transferred=!error;
     // An interrupted response may follow a completed transfer. Certification decides.
    }
   }
   await call({action:'finish',id:attempt.evidenceId});retry.current=null;form.reset();setMessage('File format checked and ready for finance review.');router.refresh();
  }catch(error){setMessage(error instanceof Error?error.message:'Upload interrupted. Retry the same file.');router.refresh();}finally{working.current=false;setBusy(false);}
 }
 async function action(id:string,operation:'download'|'withdraw'|'finish'){
  if(working.current||operation!=='download'&&(!editable||operation==='finish'&&!enabled))return;
  working.current=true;setBusy(true);setMessage('');
  try{
   if(operation==='download'){
    const response=await fetch(`/api/staff/invoice-evidence?id=${encodeURIComponent(id)}`,{cache:'no-store'}),result=await response.json();
    if(!response.ok)throw new Error(result.error||'Download unavailable.');window.location.assign(result.url);
   }else{await call({action:operation,id});router.refresh();setMessage(operation==='withdraw'?'File withdrawn.':'File format checked and ready for review.');}
  }catch(error){setMessage(error instanceof Error?error.message:'Evidence action failed.');}finally{working.current=false;setBusy(false);}
 }
 return <section aria-label="Invoice source documents"><h2>Invoice documents</h2><p>Attach the vendor invoice and relevant supporting documents. Format checks do not verify the vendor, invoice contents or entitlement to payment. Uploads and withdrawals stop when review begins.</p>{reviewedVersion&&<p>These documents are frozen for review at revision {reviewedVersion}.</p>}{files.length?files.map(file=><article className="staff-editor" key={file.id}><h3>{file.file_name}</h3><p>{file.kind==='invoice'?'Vendor invoice':'Supporting document'} · {file.state==='uploaded'?'Format checked · Ready for review':'Upload awaiting verification'}</p>{file.state==='uploaded'&&<button type="button" disabled={busy} onClick={()=>action(file.id,'download')}>Download document</button>}{editable&&file.state==='reserved'&&Date.parse(file.expires_at)>Date.now()&&<button type="button" disabled={busy||!enabled} onClick={()=>action(file.id,'finish')}>Verify uploaded file</button>}{editable&&<button type="button" disabled={busy} onClick={()=>action(file.id,'withdraw')}>Withdraw document</button>}</article>):<p>No current invoice documents.</p>}{editable&&(enabled?<form className="staff-editor" onSubmit={upload}><fieldset disabled={busy}><label>Document purpose<select name="kind" defaultValue="invoice"><option value="invoice">Vendor invoice</option><option value="supporting">Supporting document</option></select></label><label>PDF, JPEG or PNG up to 8 MB<input name="file" type="file" accept="application/pdf,image/jpeg,image/png" required/></label><p>Up to ten current files per invoice. If interrupted, retry with the same file.</p><button className="primary">{busy?'Working…':'Upload private document'}</button></fieldset></form>:<p>Private invoice uploads are being configured. Please contact management.</p>)}<p role="status" aria-live="polite">{message}</p></section>;
}
