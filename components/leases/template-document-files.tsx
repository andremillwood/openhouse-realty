'use client';
import {useRef,useState,type FormEvent} from 'react';
import {useRouter} from 'next/navigation';
import {createClient} from '@/lib/supabase/client';
import {documentFile} from '@/lib/documents/files';
import {LEASE_TEMPLATE_BUCKET} from '@/lib/leases/template-documents';
export type TemplateDocument={id:string;user_id:string;file_name:string;state:string;expires_at:string};
export function TemplateDocumentFiles({templateId,files,currentUserId,enabled}:{templateId:string;files:TemplateDocument[];currentUserId:string;enabled:boolean}){
 const router=useRouter(),[busy,setBusy]=useState(false),[message,setMessage]=useState(''),working=useRef(false),retry=useRef<{file:File;requestId:string;id?:string;transferred?:boolean}|null>(null);
 const certified=files.some(file=>file.state==='certified'),pending=files.some(file=>file.state==='reserved'&&Date.parse(file.expires_at)>Date.now());
 async function call(body:unknown){const response=await fetch('/api/staff/lease-template-documents',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify(body),cache:'no-store'});const result=await response.json();if(!response.ok)throw new Error(result.error||'Legal document action failed.');return result;}
 async function upload(event:FormEvent<HTMLFormElement>){
  event.preventDefault();if(working.current||!enabled||certified)return;
  const form=event.currentTarget,file=(form.elements.namedItem('file') as HTMLInputElement).files?.[0];if(!file)return;
  working.current=true;setBusy(true);setMessage('');
  try{
   documentFile(file.name,'application/pdf',file.size);
   if(retry.current?.file!==file)retry.current={file,requestId:crypto.randomUUID()};
   const attempt=retry.current;
   if(!attempt.transferred){const reservation=await call({action:'reserve',template_id:templateId,request_id:attempt.requestId,file_name:file.name,size:file.size});attempt.id=reservation.id;
    if(reservation.state==='certified')attempt.transferred=true;
    else{const {error}=await createClient().storage.from(LEASE_TEMPLATE_BUCKET).uploadToSignedUrl(reservation.path,reservation.token,file,{contentType:'application/pdf'});attempt.transferred=!error;}
   }
   await call({action:'finish',id:attempt.id});retry.current=null;form.reset();setMessage('PDF matches the approved template fingerprint.');router.refresh();
  }catch(error){setMessage(error instanceof Error?error.message:'Upload interrupted. Retry the same file.');router.refresh();}finally{working.current=false;setBusy(false);}
 }
 async function action(id:string,operation:'download'|'finish'|'withdraw'){
  if(working.current)return;
  const file=files.find(file=>file.id===id);if(!file||operation!=='download'&&(file.user_id!==currentUserId||file.state!=='reserved'||operation==='finish'&&!enabled))return;
  working.current=true;setBusy(true);setMessage('');
  try{if(operation==='download'){const response=await fetch(`/api/staff/lease-template-documents?id=${encodeURIComponent(id)}`,{cache:'no-store'}),result=await response.json();if(!response.ok)throw new Error(result.error||'Download unavailable.');window.location.assign(result.url);}
   else{await call({action:operation,id});if(operation==='withdraw'&&retry.current?.id===id)retry.current=null;setMessage(operation==='withdraw'?'Reservation withdrawn.':'PDF matches the approved template fingerprint.');router.refresh();}
  }catch(error){setMessage(error instanceof Error?error.message:'Legal document action failed.');}finally{working.current=false;setBusy(false);}
 }
 return <section aria-label="Approved template PDF"><h3>Approved PDF</h3><p>Upload the exact PDF reviewed for this template version. Its fingerprint must match the registered source. Certification does not sign a lease.</p>{files.map(file=><article key={file.id}><p>{file.file_name} · {file.state==='certified'?'Approved fingerprint matched':Date.parse(file.expires_at)>Date.now()?'Awaiting verification':'Reservation expired'}</p>{file.state==='certified'&&<button disabled={busy} type="button" onClick={()=>action(file.id,'download')}>Download approved PDF</button>}{file.state==='reserved'&&file.user_id===currentUserId&&<>{Date.parse(file.expires_at)>Date.now()&&<button disabled={busy||!enabled} type="button" onClick={()=>action(file.id,'finish')}>Verify uploaded PDF</button>}<button disabled={busy} type="button" onClick={()=>action(file.id,'withdraw')}>Withdraw reservation</button></>}</article>)}{!certified&&(enabled?<form onSubmit={upload} className="staff-editor"><fieldset disabled={busy}><label>Approved PDF up to 8 MB<input type="file" name="file" accept="application/pdf" required/></label>{pending&&<p>An upload is reserved. Retry the same file, verify an uploaded PDF, or withdraw your reservation before choosing another file.</p>}<button className="primary">{busy?'Working…':'Upload approved PDF'}</button></fieldset></form>:<p>Private legal uploads are being configured.</p>)}<p role="status" aria-live="polite">{message}</p></section>;
}
