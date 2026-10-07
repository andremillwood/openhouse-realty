'use client';
import {useRef,useState,type FormEvent} from 'react';
import {useRouter} from 'next/navigation';
import {AccountPicker} from '@/components/finance/account-picker';
import {invoicePostingInput} from '@/lib/finance/invoice-posting';
export function InvoicePostingForm({invoiceId,version,amount}:{invoiceId:string;version:number;amount:string}){
 const [debit,setDebit]=useState(''),[credit,setCredit]=useState(''),[busy,setBusy]=useState(false),[message,setMessage]=useState('');
 const lock=useRef(false),retry=useRef<{payload:string;id:string}|null>(null),router=useRouter();
 async function submit(event:FormEvent<HTMLFormElement>){
  event.preventDefault();if(lock.current)return;lock.current=true;setBusy(true);setMessage('');
  try{
   const values=new FormData(event.currentTarget),input={invoice_id:invoiceId,version,debit_account_id:debit,credit_account_id:credit,reason:String(values.get('reason')||''),approved:values.get('approved')==='on'};
   const payload=JSON.stringify(input);if(retry.current?.payload!==payload)retry.current={payload,id:crypto.randomUUID()};const body={...input,request_id:retry.current.id};invoicePostingInput(body);
   const response=await fetch('/api/staff/invoice-postings',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify(body)}),result=await response.json();
   if(!response.ok){if(response.status<500)retry.current=null;throw new Error(result.error||'Unable to confirm invoice posting.');}
   retry.current=null;router.push(`/staff/finance/journals/${result.journal_id}`);router.refresh();
  }catch(error){setMessage(error instanceof Error?error.message:'Result uncertain. Retry unchanged details.');}finally{lock.current=false;setBusy(false);}
 }
 return <section aria-label="Approved invoice accounting"><h2>Post approved invoice</h2><p>Post {amount} using approved chart accounts. Confirm the expense or asset debit and payable liability credit with finance. This posts the approved gross amount. It does not pay the vendor or allocate tax.</p><form className="staff-editor" onSubmit={submit}><fieldset disabled={busy}><h3>Debit · Expense or asset account</h3><AccountPicker value={debit} onChange={setDebit} accountClasses={['expense','asset']}/><h3>Credit · Payable liability account</h3><AccountPicker value={credit} onChange={setCredit} accountClasses={['liability']}/><label>Accounting approval reason<textarea name="reason" required minLength={5} maxLength={500}/></label><label><input name="approved" type="checkbox" required/> I verified the invoice approval, account classification and exact posting amount.</label><button className="primary" disabled={!debit||!credit||debit===credit}>{busy?'Posting…':'Approve and post invoice'}</button></fieldset><p role="status" aria-live="polite">{message}</p></form></section>;
}
