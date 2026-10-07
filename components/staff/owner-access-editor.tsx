'use client';
import { useRef, useState, type FormEvent } from 'react';
import { ownerAccessInput } from '@/lib/owners/access-validation';
export function OwnerAccessEditor({propertyId,access}:{propertyId:string;access?:{id:string;user_id:string;is_active:boolean;version:number}}) {
  const [busy,setBusy]=useState(false),[message,setMessage]=useState('');
  const retry=useRef<{payload:string;id:string}|null>(null);
  async function submit(event:FormEvent<HTMLFormElement>) {
    event.preventDefault(); const element=event.currentTarget;const form=new FormData(element);
    const input={access_id:access?.id||null,version:access?.version||0,property_id:access?null:propertyId,email:access?null:String(form.get('email')||''),is_active:access?form.get('is_active')==='on':true,reason:String(form.get('reason')||''),approved:form.get('approved')==='on'};
    const payload=JSON.stringify(input);if(retry.current?.payload!==payload)retry.current={payload,id:crypto.randomUUID()};
    setBusy(true);setMessage('');
    try {
      const body={...input,request_id:retry.current.id};ownerAccessInput(body);
      const response=await fetch('/api/staff/owner-access',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify(body)});
      const result=await response.json();if(!response.ok){if(response.status<500)retry.current=null;throw new Error(result.error||'Unable to save owner access.');}
      window.location.reload();
    } catch(error) {setMessage(error instanceof Error?error.message:'Unable to save access. Retry the same request.');}
    finally {setBusy(false);}
  }
  return <form className="staff-editor" onSubmit={submit}><fieldset disabled={busy}><legend>{access?'Review owner access':'Grant owner access'}</legend>{access?<><p>Account reference: {access.user_id} · Revision {access.version}</p><label><input name="is_active" type="checkbox" defaultChecked={access.is_active}/> Active portfolio access</label></>:<label>Approved verified account email<input name="email" type="email" required maxLength={254}/></label>}<label>Approval / change reason<textarea name="reason" required minLength={5} maxLength={500}/></label><label><input name="approved" type="checkbox" required/> Open House approved this property access or change.</label><button className="primary">{busy?'Saving…':access?'Save access change':'Grant access'}</button></fieldset><p role="status">{message}</p></form>;
}
