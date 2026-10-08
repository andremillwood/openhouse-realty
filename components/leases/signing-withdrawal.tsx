'use client';
import {useRef,useState,type FormEvent} from 'react';
import {useRouter} from 'next/navigation';
import {uuidPattern} from '@/lib/enquiries/validation';
export function LeaseSigningWithdrawalForm({signingId}:{signingId:string}){
 const router=useRouter();const active=useRef(false),completed=useRef(false),attempt=useRef<{request_id:string;reason:string}|null>(null);
 const [busy,setBusy]=useState(false),[uncertain,setUncertain]=useState(false),[notice,setNotice]=useState('');
 async function submit(event:FormEvent<HTMLFormElement>){
  event.preventDefault();if(active.current||completed.current)return;
  if(!attempt.current){const form=new FormData(event.currentTarget);if(form.get('approved')!=='on')return;attempt.current={request_id:crypto.randomUUID(),reason:String(form.get('reference')||'').trim()};}
  active.current=true;setBusy(true);setNotice('');
  try{
   const response=await fetch('/api/staff/lease-signing/withdraw',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({signing_id:signingId,...attempt.current,approved:true})});
   const result=await response.json();
   if(!response.ok){if(response.status>=500||uncertain){setUncertain(true);setNotice('Withdrawal is unconfirmed. Retry the same request or refresh to check the recorded signing request.');}else{attempt.current=null;setNotice(response.status===409?'Draft or signing request changed. Refresh before trying again.':response.status===403?'Independent verified staff access is required.':'Check the signing request approval and current applicant contact.');}if(response.status===409)router.refresh();return;}
   if(!result||typeof result.id!=='string'||!uuidPattern.test(result.id)||result.signing_id!==signingId||result.state!=='withdrawn')throw new Error('Unconfirmed response');
   completed.current=true;setUncertain(false);setNotice(`Withdrawal is recorded. The original signing approval remains in history.`);router.refresh();
  }catch{setUncertain(true);setNotice('Withdrawal is unconfirmed. Retry the same request or refresh to check the recorded signing request.');}
  finally{active.current=false;setBusy(false);}
 }
 return <form onSubmit={submit}><h4>Withdraw signing request</h4><p>Withdraw this request before provider dispatch. Its original approval remains in the audit history. This does not cancel a signed lease or change resident access.</p><fieldset disabled={busy||uncertain||completed.current}><label>Withdrawal reason<textarea name="reference" required minLength={5} maxLength={500}/></label><label><input name="approved" type="checkbox" required/>I approve withdrawing this pending signing request.</label></fieldset><button disabled={busy||completed.current}>{busy?'Withdrawing…':uncertain?'Retry the same withdrawal':'Withdraw pending request'}</button><p role="status">{notice}</p></form>;
}
