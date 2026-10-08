'use client';
import {useRef,useState,type FormEvent} from 'react';
import {useRouter} from 'next/navigation';
import {uuidPattern} from '@/lib/enquiries/validation';
import {serviceTargetInput,type ServiceTargetKind} from '@/lib/staff/service-targets';
export function ServiceTargetForm({workOrderId,workOrderVersion,kind,version}:{workOrderId:string;workOrderVersion:number;kind:ServiceTargetKind;version:number}){
 const router=useRouter(),active=useRef(false),completed=useRef(false),attempt=useRef<ReturnType<typeof serviceTargetInput>|null>(null);
 const [busy,setBusy]=useState(false),[uncertain,setUncertain]=useState(false),[notice,setNotice]=useState(''),[action,setAction]=useState('set');
 async function submit(event:FormEvent<HTMLFormElement>){
  event.preventDefault();if(active.current||completed.current)return;
  if(!attempt.current){try{const form=new FormData(event.currentTarget);attempt.current=serviceTargetInput({work_order_id:workOrderId,work_order_version:workOrderVersion,kind,version,action,due_at:action==='set'?form.get('due_at'):null,reason:form.get('reason'),request_id:crypto.randomUUID(),approved:form.get('approved')==='on'});}catch{setNotice('Approve an explained target with a valid Jamaica date and time, or clear it explicitly.');return;}}
  const input=attempt.current;active.current=true;setBusy(true);setNotice('');
  try{
   const due=input.p_due_at===null?null:new Date(Date.parse(input.p_due_at)-5*60*60*1000).toISOString().slice(0,16);
   const response=await fetch('/api/staff/service-targets',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({work_order_id:input.p_work_order_id,work_order_version:input.p_expected_work_order_version,kind:input.p_kind,version:input.p_expected_version,action:input.p_action,due_at:due,reason:input.p_reason,request_id:input.p_request_id,approved:true})});
   const result=await response.json();
   if(!response.ok){if(response.status>=500||uncertain){setUncertain(true);setNotice('Target is unconfirmed. Retry the same request or refresh to inspect history.');}else{attempt.current=null;setNotice(response.status===409?'The work order or target changed. Refresh before trying again.':response.status===403?'Verified organization management access is required.':'Check target approval, future date and explanation.');}if(response.status===409)router.refresh();return;}
   if(!result||typeof result.id!=='string'||!uuidPattern.test(result.id)||result.work_order_id!==input.p_work_order_id||result.work_order_version!==input.p_expected_work_order_version||result.kind!==input.p_kind||result.version!==input.p_expected_version+1||result.action!==input.p_action||result.due_at!==input.p_due_at)throw Error();
   completed.current=true;setUncertain(false);setNotice('Target decision recorded. Response and completion are recorded separately.');router.refresh();
  }catch{setUncertain(true);setNotice('Target is unconfirmed. Retry the same request or refresh to inspect history.');}
  finally{active.current=false;setBusy(false);}
 }
 return <form className="service-target-form" onSubmit={submit}><h3>Update {kind} target</h3><p>Target revision {version}. Enter dates in Jamaica time.</p><fieldset disabled={busy||uncertain||completed.current}><label>Action<select value={action} onChange={event=>setAction(event.target.value)}><option value="set">Set or replace target</option><option value="clear">Clear target</option></select></label>{action==='set'&&<label>Target date and time · Jamaica<input name="due_at" type="datetime-local" required/></label>}<label>Explanation<textarea name="reason" required minLength={5} maxLength={500}/></label><label><input name="approved" type="checkbox" required/>I approve this target decision for this work order.</label></fieldset><button disabled={busy||completed.current}>{busy?'Recording…':uncertain?'Retry the same target':'Record target decision'}</button><p role="status">{notice}</p></form>;
}
