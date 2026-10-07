'use client';
import {useRef,useState,type FormEvent} from 'react';
import {useRouter} from 'next/navigation';
import {AccountPicker} from '@/components/finance/account-picker';
import {chequePostingInput} from '@/lib/finance/cheque-posting';
export function ChequePostingForm({chequeId,version,amount}:{chequeId:string;version:number;amount:string}){
 const [debit,setDebit]=useState(''),[credit,setCredit]=useState(''),[busy,setBusy]=useState(false),[message,setMessage]=useState('');
 const lock=useRef(false),retry=useRef<{payload:string;id:string}|null>(null),router=useRouter();
 async function submit(event:FormEvent<HTMLFormElement>){
  event.preventDefault();if(lock.current)return;lock.current=true;setBusy(true);setMessage('');
  try{
   const values=new FormData(event.currentTarget),input={cheque_id:chequeId,version,debit_account_id:debit,credit_account_id:credit,reason:String(values.get('reason')||''),approved:values.get('approved')==='on'};
   const payload=JSON.stringify(input);if(retry.current?.payload!==payload)retry.current={payload,id:crypto.randomUUID()};const body={...input,request_id:retry.current.id};chequePostingInput(body);
   const response=await fetch('/api/staff/cheque-postings',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify(body)}),result=await response.json();
   if(!response.ok){if(response.status<500)retry.current=null;throw new Error(result.error||'Unable to confirm cheque posting.');}
   retry.current=null;router.push(`/staff/finance/journals/${result.journal_id}`);router.refresh();
  }catch(error){setMessage(error instanceof Error?error.message:'Result uncertain. Retry unchanged details.');}finally{lock.current=false;setBusy(false);}
 }
 return <section aria-label="Cleared cheque accounting"><h2>Post cleared cheque</h2><p>Post {amount} using approved chart accounts. Confirm the bank asset account and the appropriate credit account with finance. This does not allocate a resident payment. A later approved bank return reverses this journal.</p><form className="staff-editor" onSubmit={submit}><fieldset disabled={busy}><h3>Debit · Bank asset account</h3><AccountPicker value={debit} onChange={setDebit} accountClasses={['asset']}/><h3>Credit · Approved accounting account</h3><AccountPicker value={credit} onChange={setCredit}/><label>Accounting approval reason<textarea name="reason" required minLength={5} maxLength={500}/></label><label><input name="approved" type="checkbox" required/> I verified the clearance, account classification and exact posting amount.</label><button className="primary" disabled={!debit||!credit||debit===credit}>{busy?'Posting…':'Approve and post cheque'}</button></fieldset><p role="status" aria-live="polite">{message}</p></form></section>;
}
