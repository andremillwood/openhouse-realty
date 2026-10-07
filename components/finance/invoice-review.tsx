'use client';
import {useRef,useState,type FormEvent} from 'react';
import {invoiceInput} from '@/lib/finance/invoice-validation';
export function InvoiceReview({invoiceId,version,actions}:{invoiceId:string;version:number;actions:('review'|'approve'|'reject')[]}) {
 const [busy,setBusy]=useState(false),[message,setMessage]=useState('');const retry=useRef<{payload:string;id:string}|null>(null);
 async function submit(event:FormEvent<HTMLFormElement>) {
  event.preventDefault();const form=new FormData(event.currentTarget);setBusy(true);setMessage('');
  try {
   const action=String(form.get('action')||'');if(!actions.includes(action as 'review'|'approve'|'reject'))throw new Error('Choose an available review action.');
   const input={action,invoice_id:invoiceId,version,property_id:null,work_order_id:null,vendor_name:null,invoice_number:null,amount_minor:null,reason:String(form.get('reason')||''),approved:form.get('approved')==='on'};
   const payload=JSON.stringify(input);if(retry.current?.payload!==payload)retry.current={payload,id:crypto.randomUUID()};const body={...input,request_id:retry.current.id};invoiceInput(body);
   const response=await fetch('/api/staff/invoices',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify(body)});const result=await response.json();if(!response.ok){if(response.status<500)retry.current=null;throw new Error(result.error||'Unable to record review.');}window.location.reload();
  }catch(error){setMessage(error instanceof Error?error.message:'Unable to record review. Retry the same request.');}finally{setBusy(false);}
 }
 if(!actions.length)return null;
 return <form className="staff-editor" onSubmit={submit}><fieldset disabled={busy}><legend>Independent invoice review</legend><label>Action<select name="action" defaultValue="" required><option value="" disabled>Choose action</option>{actions.map(action=><option key={action} value={action}>{action==='review'?'Record review':action==='approve'?'Approve invoice':'Reject invoice'}</option>)}</select></label><label>Review / decision reason<textarea name="reason" required minLength={5} maxLength={500}/></label><label><input name="approved" type="checkbox" required/> I independently checked this invoice and approve the selected decision.</label><p>Approval records a decision. It does not pay the vendor or post to the ledger.</p><button className="primary">{busy?'Saving…':'Record decision'}</button></fieldset><p role="status">{message}</p></form>;
}
