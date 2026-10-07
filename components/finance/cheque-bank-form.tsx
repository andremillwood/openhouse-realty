'use client';
import {useRef,useState,type FormEvent} from 'react';
import {useRouter} from 'next/navigation';
import {chequeInput} from '@/lib/finance/cheque-validation';
type Evidence={id:string;kind:string;file_name:string};
export function ChequeBankForm({chequeId,version,state,files}:{chequeId:string;version:number;state:string;files:Evidence[]}){
 const options=state==='received'?[{action:'record_deposit',kind:'deposit',label:'Record bank deposit'}]:state==='deposited'?[{action:'confirm_clear',kind:'clearance',label:'Record bank clearance'},{action:'record_return',kind:'return',label:'Record bank return'}]:state==='cleared'?[{action:'record_return',kind:'return',label:'Record bank return'}]:[];
 const [action,setAction]=useState(options[0]?.action||''),[busy,setBusy]=useState(false),[message,setMessage]=useState('');
 const lock=useRef(false),retry=useRef<{payload:string;id:string}|null>(null),router=useRouter();
 const selected=options.find(option=>option.action===action),available=files.filter(file=>file.kind===selected?.kind);
 async function submit(event:FormEvent<HTMLFormElement>){
  event.preventDefault();if(lock.current||!selected||!available.length)return;
  const form=event.currentTarget;lock.current=true;setBusy(true);setMessage('');
  try{
   const values=new FormData(form),evidence=String(values.get('evidence_id')||'');
   if(!available.some(file=>file.id===evidence))throw new Error('Select a current certified bank document.');
   const input={action,cheque_id:chequeId,version,evidence_id:evidence,bank_reference:String(values.get('bank_reference')||''),reason:String(values.get('reason')||''),approved:values.get('approved')==='on'};
   const payload=JSON.stringify(input);if(retry.current?.payload!==payload)retry.current={payload,id:crypto.randomUUID()};
   const body={...input,request_id:retry.current.id};chequeInput(body);
   const response=await fetch('/api/staff/cheques',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify(body)}),result=await response.json();
   if(!response.ok){if(response.status<500)retry.current=null;throw new Error(result.error||'Unable to save bank decision.');}
   retry.current=null;form.reset();setMessage('Bank decision recorded. The selected document is retained in the audit history.');router.refresh();
  }catch(error){setMessage(error instanceof Error?error.message:'Result uncertain. Retry unchanged details.');}finally{lock.current=false;setBusy(false);}
 }
 if(!options.length)return null;
 return <section aria-label="Approved cheque bank decision"><h2>Record a bank decision</h2><p>Check the bank record before approving. Deposit and clearance record custody and preserve the selected document. An approved return reverses any linked cleared-cheque journal. Resident balance allocation is handled separately.</p><form className="staff-editor" onSubmit={submit}><fieldset disabled={busy}><label>Bank action<select value={action} onChange={event=>{setAction(event.target.value);setMessage('');}}>{options.map(option=><option key={option.action} value={option.action}>{option.label}</option>)}</select></label>{available.length?<label>Certified bank document<select key={action} name="evidence_id" required defaultValue=""><option value="" disabled>Select a document</option>{available.map(file=><option key={file.id} value={file.id}>{file.file_name}</option>)}</select></label>:<p role="status">Upload and verify {selected?.kind} evidence before recording this action.</p>}<label>Bank reference<input name="bank_reference" required minLength={3} maxLength={120}/></label><label>Approval reason<textarea name="reason" required minLength={5} maxLength={500}/></label><label><input type="checkbox" name="approved" required/> I checked the bank evidence and approve this decision.</label><button className="primary" disabled={!available.length}>{busy?'Saving…':selected?.label}</button></fieldset><p role="status" aria-live="polite">{message}</p></form></section>;
}
