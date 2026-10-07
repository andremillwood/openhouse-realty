'use client';
import {useRef,useState,type FormEvent} from 'react';
import {useRouter} from 'next/navigation';
import {DimensionPicker} from '@/components/finance/dimension-picker';
import {jmdMinor} from '@/lib/finance/money';
import {chequeInput} from '@/lib/finance/cheque-validation';
export function ChequeForm({receipt}:{receipt?:{id:string;version:number}}){
 const router=useRouter(),lock=useRef(false),retry=useRef<{payload:string;id:string}|null>(null);
 const [property,setProperty]=useState(''),[busy,setBusy]=useState(false),[message,setMessage]=useState('');
 async function submit(event:FormEvent<HTMLFormElement>){event.preventDefault();if(lock.current)return;lock.current=true;setBusy(true);setMessage('');
 try{const form=new FormData(event.currentTarget),input={action:receipt?'cancel':'receive',cheque_id:receipt?.id||null,version:receipt?.version||0,property_id:receipt?null:property||null,payer_name:receipt?null:String(form.get('payer_name')||''),bank_name:receipt?null:String(form.get('bank_name')||''),cheque_reference:receipt?null:String(form.get('cheque_reference')||''),amount_minor:receipt?null:jmdMinor(String(form.get('amount')||'')),reason:String(form.get('reason')||''),approved:form.get('approved')==='on'};
 const payload=JSON.stringify(input);if(retry.current?.payload!==payload)retry.current={payload,id:crypto.randomUUID()};const body={...input,request_id:retry.current.id};chequeInput(body);
 const response=await fetch('/api/staff/cheques',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify(body)}),result=await response.json();
 if(!response.ok){if(response.status<500)retry.current=null;throw new Error(result.error||'Unable to save cheque custody.');}
 retry.current=null;setMessage(receipt?'Cheque cancelled.':'Cheque receipt recorded.');router.refresh();
 }catch(error){setMessage(error instanceof Error?error.message:'Unable to confirm the result. Retry unchanged details.');}finally{lock.current=false;setBusy(false);}}
 return <form className="staff-editor" onSubmit={submit}><fieldset disabled={busy}><legend>{receipt?'Cancel this received cheque':'Record an incoming cheque'}</legend>{!receipt&&<><DimensionPicker kind="property" value={property} onChange={setProperty}/><label>Payer name<input name="payer_name" required minLength={2} maxLength={160}/></label><label>Bank name<input name="bank_name" required minLength={2} maxLength={160}/></label><label>Cheque reference<input name="cheque_reference" required maxLength={80}/></label><label>Amount (JMD)<input name="amount" inputMode="decimal" required maxLength={15}/><small>Use up to two decimal places without commas.</small></label></>}<p>{receipt?'Cancellation closes this custody receipt. It does not record a returned bank payment.':'Receipt records custody only. It does not confirm bank clearance or credit a resident balance.'}</p><label>Approval reason<textarea name="reason" required minLength={5} maxLength={500}/></label><label><input name="approved" type="checkbox" required/> I checked the cheque details and this custody action is approved.</label><button className="primary">{busy?'Saving…':receipt?'Cancel cheque receipt':'Record receipt'}</button></fieldset><p role="status">{message}</p></form>;
}
