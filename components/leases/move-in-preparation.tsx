'use client';
import {useRef,useState,type FormEvent} from 'react';
import {useRouter} from 'next/navigation';
import {uuidPattern} from '@/lib/enquiries/validation';
import {moveInPreparationInput,type MoveInPreparationKind} from '@/lib/leases/move-in';
export function MoveInPreparationForm({draftId,draftVersion,kind,version}:{draftId:string;draftVersion:number;kind:MoveInPreparationKind;version:number}){
 const router=useRouter(),active=useRef(false),completed=useRef(false),attempt=useRef<ReturnType<typeof moveInPreparationInput>|null>(null);
 const [busy,setBusy]=useState(false),[uncertain,setUncertain]=useState(false),[notice,setNotice]=useState('');
 async function submit(event:FormEvent<HTMLFormElement>){
  event.preventDefault();if(active.current||completed.current)return;
  if(!attempt.current){try{const form=new FormData(event.currentTarget);attempt.current=moveInPreparationInput({draft_id:draftId,draft_version:draftVersion,kind,version,state:form.get('state'),evidence_reference:form.get('evidence'),reason:form.get('reason'),request_id:crypto.randomUUID(),approved:form.get('approved')==='on'});}catch{setNotice('Approve the status and explanation; ready items require an evidence reference.');return;}}
  const input=attempt.current;active.current=true;setBusy(true);setNotice('');
  try{
   const response=await fetch('/api/staff/move-in-preparation',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({draft_id:input.p_draft_id,draft_version:input.p_expected_draft_version,kind:input.p_kind,version:input.p_expected_version,state:input.p_state,evidence_reference:input.p_evidence_reference,reason:input.p_reason,request_id:input.p_request_id,approved:true})});
   const result=await response.json();
   if(!response.ok){if(response.status>=500||uncertain){setUncertain(true);setNotice('Preparation is unconfirmed. Retry the same request or refresh to inspect history.');}else{attempt.current=null;setNotice(response.status===409?'Preparation or approval changed. Refresh before trying again.':response.status===403?'Independent verified staff access is required.':'Check preparation approval and evidence.');}if(response.status===409)router.refresh();return;}
   if(!result||typeof result.id!=='string'||!uuidPattern.test(result.id)||result.draft_id!==input.p_draft_id||result.kind!==input.p_kind||result.version!==input.p_expected_version+1||result.state!==input.p_state)throw Error();
   completed.current=true;setUncertain(false);setNotice('Preparation is recorded. This does not activate a tenancy or confirm payment.');router.refresh();
  }catch{setUncertain(true);setNotice('Preparation is unconfirmed. Retry the same request or refresh to inspect history.');}
  finally{active.current=false;setBusy(false);}
 }
 return <form onSubmit={submit}><h3>{kind.replaceAll('_',' ')}</h3><p>Preparation revision {version}. Retain evidence for readiness; access handover requires separately approved activation.</p><fieldset disabled={busy||uncertain||completed.current}><label>Status<select name="state" defaultValue="pending"><option value="pending">Pending</option><option value="ready">Ready</option><option value="blocked">Blocked</option></select></label><label>Evidence reference<input name="evidence" maxLength={500}/></label><label>Explanation<textarea name="reason" required minLength={5} maxLength={500}/></label><label><input name="approved" type="checkbox" required/>I approve this preparation record for this draft.</label></fieldset><button disabled={busy||completed.current}>{busy?'Recording…':uncertain?'Retry the same preparation':'Record preparation'}</button><p role="status">{notice}</p></form>;
}
