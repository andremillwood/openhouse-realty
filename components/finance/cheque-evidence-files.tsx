'use client';
import {useRef,useState,type FormEvent} from 'react';
import {useRouter} from 'next/navigation';
import {createClient} from '@/lib/supabase/client';
import {documentFile} from '@/lib/documents/files';
import {CHEQUE_EVIDENCE_BUCKET} from '@/lib/finance/cheque-evidence';
export type ChequeEvidenceFile={id:string;user_id:string;kind:string;file_name:string;state:string;expires_at:string;frozen_version?:number};
export function ChequeEvidenceFiles({files,chequeId,editable=false,enabled=false,reviewedVersion,currentUserId}:{files:ChequeEvidenceFile[];chequeId:string;editable?:boolean;enabled?:boolean;reviewedVersion?:number;currentUserId:string}){
 const router=useRouter(),[busy,setBusy]=useState(false),[message,setMessage]=useState(''),working=useRef(false);
 const retry=useRef<{file:File;kind:string;requestId:string;evidenceId?:string;transferred?:boolean}|null>(null);
 async function call(body:unknown){
  const response=await fetch('/api/staff/cheque-evidence',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify(body),cache:'no-store'});
  const result=await response.json();if(!response.ok)throw new Error(result.error||'Cheque evidence action failed.');return result;
 }
 async function upload(event:FormEvent<HTMLFormElement>){
  event.preventDefault();if(working.current||!editable||!enabled)return;
  const form=event.currentTarget,file=(form.elements.namedItem('file') as HTMLInputElement).files?.[0],kind=(form.elements.namedItem('kind') as HTMLSelectElement).value;
  if(!file)return;working.current=true;setBusy(true);setMessage('');
  try{
   documentFile(file.name,file.type,file.size);if(!['deposit','clearance','return'].includes(kind))throw new Error('Choose deposit, clearance or return evidence.');
   if(retry.current?.file!==file||retry.current.kind!==kind)retry.current={file,kind,requestId:crypto.randomUUID()};
   const attempt=retry.current;
   if(!attempt.transferred){
    const result=await call({action:'reserve',cheque_id:chequeId,request_id:attempt.requestId,kind,file_name:file.name,mime_type:file.type,size:file.size});
    attempt.evidenceId=result.id;
    if(result.state==='uploaded')attempt.transferred=true;
    else{
     const {error}=await createClient().storage.from(CHEQUE_EVIDENCE_BUCKET).uploadToSignedUrl(result.path,result.token,file,{contentType:file.type});
     attempt.transferred=!error;
     // An interrupted response may follow a completed transfer. Certification decides.
    }
   }
   await call({action:'finish',id:attempt.evidenceId});retry.current=null;form.reset();setMessage('File format checked and ready for finance review.');router.refresh();
  }catch(error){setMessage(error instanceof Error?error.message:'Upload interrupted. Retry the same file.');router.refresh();}finally{working.current=false;setBusy(false);}
 }
 async function action(id:string,operation:'download'|'withdraw'|'finish'){
  if(working.current||operation!=='download'&&(!editable||operation==='finish'&&!enabled))return;
  if(operation!=='download'&&!files.some(file=>file.id===id&&file.user_id===currentUserId&&!file.frozen_version))return;
  working.current=true;setBusy(true);setMessage('');
  try{
   if(operation==='download'){
    const response=await fetch(`/api/staff/cheque-evidence?id=${encodeURIComponent(id)}`,{cache:'no-store'}),result=await response.json();
    if(!response.ok)throw new Error(result.error||'Download unavailable.');window.location.assign(result.url);
   }else{await call({action:operation,id});router.refresh();setMessage(operation==='withdraw'?'File withdrawn.':'File format checked and ready for review.');}
  }catch(error){setMessage(error instanceof Error?error.message:'Evidence action failed.');}finally{working.current=false;setBusy(false);}
 }
 return <section aria-label="Cheque bank documents"><h2>Bank evidence</h2><p>Attach bank deposit, clearance or return evidence. Format checks do not verify bank authenticity or confirm cleared funds. Bank decisions require a separate approved review.</p>{reviewedVersion&&<p>These documents are frozen for review at revision {reviewedVersion}.</p>}{files.length?files.map(file=><article className="staff-editor" key={file.id}><h3>{file.file_name}</h3><p>{file.kind==='deposit'?'Deposit evidence':file.kind==='clearance'?'Clearance evidence':'Return evidence'} · {file.state==='uploaded'?'Format checked · Ready for review':'Upload awaiting verification'}</p>{file.state==='uploaded'&&<button type="button" disabled={busy} onClick={()=>action(file.id,'download')}>Download document</button>}{editable&&file.user_id===currentUserId&&file.state==='reserved'&&Date.parse(file.expires_at)>Date.now()&&<button type="button" disabled={busy||!enabled} onClick={()=>action(file.id,'finish')}>Verify uploaded file</button>}{file.frozen_version&&<p>Retained for bank decision at revision {file.frozen_version}.</p>}{editable&&!file.frozen_version&&file.user_id===currentUserId&&<button type="button" disabled={busy} onClick={()=>action(file.id,'withdraw')}>Withdraw document</button>}</article>):<p>No current bank documents.</p>}{editable&&(enabled?<form className="staff-editor" onSubmit={upload}><fieldset disabled={busy}><label>Document purpose<select name="kind" defaultValue="deposit"><option value="deposit">Deposit evidence</option><option value="clearance">Clearance evidence</option><option value="return">Return evidence</option></select></label><label>PDF, JPEG or PNG up to 8 MB<input name="file" type="file" accept="application/pdf,image/jpeg,image/png" required/></label><p>Up to ten current files per cheque. If interrupted, retry with the same file.</p><button className="primary">{busy?'Working…':'Upload private document'}</button></fieldset></form>:<p>Private cheque uploads are being configured. Please contact management.</p>)}<p role="status" aria-live="polite">{message}</p></section>;
}
