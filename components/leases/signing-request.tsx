'use client';
import {useRef,useState,type FormEvent} from 'react';
import {useRouter} from 'next/navigation';
import {uuidPattern} from '@/lib/enquiries/validation';
export function LeaseSigningRequestForm({applicationId,draftId,version}:{applicationId:string;draftId:string;version:number}){
 const router=useRouter();const active=useRef(false),completed=useRef(false),attempt=useRef<{request_id:string;approval_reference:string}|null>(null);
 const [busy,setBusy]=useState(false),[uncertain,setUncertain]=useState(false),[notice,setNotice]=useState('');
 async function submit(event:FormEvent<HTMLFormElement>){
  event.preventDefault();if(active.current||completed.current)return;
  if(!attempt.current){const form=new FormData(event.currentTarget);if(form.get('approved')!=='on')return;attempt.current={request_id:crypto.randomUUID(),approval_reference:String(form.get('reference')||'').trim()};}
  active.current=true;setBusy(true);setNotice('');
  try{
   const response=await fetch('/api/staff/lease-signing',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({application_id:applicationId,draft_id:draftId,draft_version:version,...attempt.current,signing_approved:true})});
   const result=await response.json();
   if(!response.ok){if(response.status>=500||uncertain){setUncertain(true);setNotice('Signing request is unconfirmed. Retry the same request or refresh to check the recorded signing request.');}else{attempt.current=null;setNotice(response.status===409?'Draft or signing request changed. Refresh before trying again.':response.status===403?'Independent verified staff access is required.':'Check the signing request approval and current applicant contact.');}if(response.status===409)router.refresh();return;}
   if(!result||typeof result.id!=='string'||!uuidPattern.test(result.id)||result.draft_id!==draftId||result.version!==version||result.state!=='awaiting_provider')throw new Error('Unconfirmed response');
   completed.current=true;setUncertain(false);setNotice(`Signing request for version ${version} is recorded and awaiting provider configuration. Legal signing has not started.`);router.refresh();
  }catch{setUncertain(true);setNotice('Signing request is unconfirmed. Retry the same request or refresh to check the recorded signing request.');}
  finally{active.current=false;setBusy(false);}
 }
 return <form onSubmit={submit}><h4>Request lease signing</h4><p>This records staff approval to request signing for this draft. Provider configuration and legal execution are still pending. It does not grant resident access or collect rent.</p><fieldset disabled={busy||uncertain||completed.current}><label>Signing approval reference<textarea name="reference" required minLength={5} maxLength={500}/></label><label><input name="approved" type="checkbox" required/>I have reviewed this draft and approve requesting legal signing for its approved participants.</label></fieldset><button disabled={busy||completed.current}>{busy?'Recording…':uncertain?'Retry the same signing request':'Record signing request'}</button><p role="status">{notice}</p></form>;
}
