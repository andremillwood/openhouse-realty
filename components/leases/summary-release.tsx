'use client';
import {useRef,useState,type FormEvent} from 'react';
import {useRouter} from 'next/navigation';
import {uuidPattern} from '@/lib/enquiries/validation';
export function LeaseSummaryRelease({applicationId,draftId,version}:{applicationId:string;draftId:string;version:number}){
 const router=useRouter();const active=useRef(false),completed=useRef(false),attempt=useRef<{request_id:string;release_reference:string}|null>(null);
 const [busy,setBusy]=useState(false),[uncertain,setUncertain]=useState(false),[notice,setNotice]=useState('');
 async function submit(event:FormEvent<HTMLFormElement>){
  event.preventDefault();if(active.current||completed.current)return;
  if(!attempt.current){const form=new FormData(event.currentTarget);if(form.get('approved')!=='on')return;attempt.current={request_id:crypto.randomUUID(),release_reference:String(form.get('reference')||'').trim()};}
  active.current=true;setBusy(true);setNotice('');
  try{
   const response=await fetch('/api/staff/lease-summaries',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({application_id:applicationId,draft_id:draftId,version,...attempt.current,sharing_approved:true})});
   const result=await response.json();
   if(!response.ok){if(response.status>=500||uncertain){setUncertain(true);setNotice('Release is unconfirmed. Retry the same request or refresh to check the recorded release.');}else{attempt.current=null;setNotice(response.status===409?'Draft or release changed. Refresh before trying again.':response.status===403?'Independent verified staff access is required.':'Check the release approval and current applicant contact.');}if(response.status===409)router.refresh();return;}
   if(!result||typeof result.id!=='string'||!uuidPattern.test(result.id)||result.draft_id!==draftId||result.version!==version||result.state!=='released')throw new Error('Unconfirmed response');
   completed.current=true;setUncertain(false);setNotice(`Release of version ${version} is recorded. Refresh to check whether it is still current. Signing has not started.`);router.refresh();
  }catch{setUncertain(true);setNotice('Release is unconfirmed. Retry the same request or refresh to check the recorded release.');}
  finally{active.current=false;setBusy(false);}
 }
 return <form onSubmit={submit}><p>Share only the home, dates, rent, deposit, billing day and template title shown above. Internal references and participant contacts remain private.</p><fieldset disabled={busy||uncertain||completed.current}><label>Internal sharing approval reference<textarea name="reference" required minLength={5} maxLength={500}/></label><label><input name="approved" type="checkbox" required/>I have reviewed this version and approve sharing its summary with the applicant.</label></fieldset><button disabled={busy||completed.current}>{busy?'Sharing…':uncertain?'Retry the same release':'Share this summary with applicant'}</button><p role="status">{notice}</p></form>;
}
