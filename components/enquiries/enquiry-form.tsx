'use client';
import {propertySignInHref} from '@/lib/auth-return';
import { useRef, useState, type FormEvent } from 'react';
export function EnquiryForm({listingId,realtorId,initialMessage=''}:{listingId?:string;realtorId?:string;initialMessage?:string}) {
  const attempt=useRef<{request_id:string;listing_id:string|null;realtor_id:string|null;contact_name:FormDataEntryValue|null;phone:FormDataEntryValue|null;message:FormDataEntryValue|null;consent:boolean}|null>(null);
  const sending=useRef(false);const completed=useRef(false);
  const [busy,setBusy]=useState(false);const [submitted,setSubmitted]=useState(false);const [message,setMessage]=useState('');const [needsSignIn,setNeedsSignIn]=useState(false);const [uncertain,setUncertain]=useState(false);
  async function submit(event:FormEvent<HTMLFormElement>){
    event.preventDefault();if(sending.current||completed.current)return;sending.current=true;setBusy(true);setMessage('');setNeedsSignIn(false);
    try{
      if(!attempt.current){const fields=new FormData(event.currentTarget);attempt.current={request_id:crypto.randomUUID(),listing_id:listingId||null,realtor_id:realtorId||null,contact_name:fields.get('contact_name'),phone:fields.get('phone'),message:fields.get('message'),consent:fields.get('consent')==='on'};}
      const response=await fetch('/api/enquiries',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify(attempt.current)});
      if(!response.ok&&response.status>=400&&response.status<500){if(response.status===401)setNeedsSignIn(true);if(uncertain){setMessage('This retry was rejected, but the earlier submission is still unconfirmed. Check your account before starting a different enquiry.');return;}attempt.current=null;setUncertain(false);const result=await response.json().catch(()=>null);setMessage(typeof result?.error==='string'?result.error:'Unable to submit. Check your details and try again.');return;}
      const result=await response.json();
      if(!response.ok||typeof result?.id!=='string'||!/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(result.id))throw new Error('Unconfirmed submission');
      completed.current=true;setUncertain(false);setSubmitted(true);setMessage('Your enquiry is stored. The team will follow up; any viewing requires confirmation.');
    }catch{setUncertain(true);setMessage('We could not confirm whether your enquiry was stored. Retry the same request below, or check your account. Your details are held unchanged for a safe retry.');}finally{sending.current=false;setBusy(false);}
  }
  return <div className="enquiry-panel">{submitted?<><h3>Your next step is underway.</h3><p role="status">{message}</p><a href="/account/enquiries">View your enquiries ↗</a></>:<form onSubmit={submit} className="staff-editor"><h3>Start a conversation.</h3><p>Sign in with your verified email to send a secure enquiry to the Open House team.</p><fieldset disabled={busy||uncertain}><label>Your name<input name="contact_name" autoComplete="name" minLength={2} maxLength={120} required/></label><label>Phone (optional)<input name="phone" type="tel" autoComplete="tel" maxLength={40}/></label><label>Your enquiry<textarea name="message" minLength={10} maxLength={4000} defaultValue={initialMessage} rows={5} required/></label><label><input name="consent" type="checkbox" required/> I agree that Open House can use these details to respond to this enquiry.</label></fieldset><button className="primary" disabled={busy}>{busy?'Sending…':uncertain?'Retry same enquiry ↗':'Send enquiry ↗'}</button><p role="status">{message}</p>{uncertain&&<a href="/account/enquiries">Check your enquiries ↗</a>}{needsSignIn&&<a href={listingId?propertySignInHref(listingId,'enquiry'):'/sign-in?next=%2Frealtors'}>Sign in or create an account ↗</a>}</form>}</div>;
}
