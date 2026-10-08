'use client';
import {propertySignInHref} from '@/lib/auth-return';
import { useRef,useState,type FormEvent } from 'react';
import { useRouter } from 'next/navigation';
import { viewingTime } from '@/lib/viewings/validation';
export type AvailableSlot={id:string;starts_at:string;ends_at:string};
export function ViewingRequest({slots,listingId}:{slots:AvailableSlot[];listingId?:string}){
 const router=useRouter();const attempt=useRef<Record<string,FormDataEntryValue|null|boolean>|null>(null);const sending=useRef(false);const completed=useRef(false);const [busy,setBusy]=useState(false);const [submitted,setSubmitted]=useState(false);const [message,setMessage]=useState('');const [signIn,setSignIn]=useState(false);const [uncertain,setUncertain]=useState(false);
 async function submit(event:FormEvent<HTMLFormElement>){
  event.preventDefault();if(sending.current||completed.current)return;sending.current=true;setBusy(true);setMessage('');setSignIn(false);
  try{
   if(!attempt.current){const data=new FormData(event.currentTarget);attempt.current={request_id:crypto.randomUUID(),slot_id:data.get('slot_id'),contact_name:data.get('contact_name'),phone:data.get('phone'),consent:data.get('consent')==='on'};}
   const response=await fetch('/api/viewings',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify(attempt.current)});
   if(!response.ok&&response.status>=400&&response.status<500){
    if(response.status===401)setSignIn(true);
    if(uncertain){setMessage('This retry was rejected, but the earlier request is still unconfirmed. Check your account before choosing another time.');return;}
    attempt.current=null;setUncertain(false);const result=await response.json().catch(()=>null);setMessage(typeof result?.error==='string'?result.error:'Unable to request this time. Check your details and try again.');return;
   }
   const result=await response.json();
   if(!response.ok||typeof result?.id!=='string'||!/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(result.id)||!['requested','confirmed','cancelled','no_show','expired','completed'].includes(result.status))throw new Error('Unconfirmed request');
   completed.current=true;setUncertain(false);setSubmitted(true);setMessage(result.status==='confirmed'?'Your viewing is confirmed. Check your account for details.':result.status==='requested'?'Your viewing request is stored. It is not confirmed until the team approves it.':'This request already has an updated status. Check your account before choosing another time.');router.refresh();
  }catch{setUncertain(true);setMessage('The viewing request could not be confirmed. Retry the same request, or check your account before choosing another time. Your original details are held unchanged.');}finally{sending.current=false;setBusy(false);}
 }

 return <section className="viewing-request"><h3>Make time for your next chapter.</h3>{submitted?<><p role="status">{message}</p><a href="/account">Track your viewing request ↗</a></>:!slots.length?<p>No public viewing times are currently available. Send an enquiry and the team will help arrange a visit.</p>:<form className="staff-editor" onSubmit={submit}><p>Choose an upcoming time in Jamaica. A request holds the slot temporarily; the team must confirm your appointment.</p><fieldset disabled={busy||uncertain}><label>Available time (Jamaica)<select name="slot_id" required defaultValue=""><option value="">Choose a time</option>{slots.map(slot=><option key={slot.id} value={slot.id}>{viewingTime(slot.starts_at)} · {Math.round((Date.parse(slot.ends_at)-Date.parse(slot.starts_at))/60000)} minutes</option>)}</select></label><label>Your name<input name="contact_name" autoComplete="name" required minLength={2} maxLength={120}/></label><label>Phone (optional)<input name="phone" type="tel" autoComplete="tel" maxLength={40}/></label><label><input name="consent" type="checkbox" required/> I agree that Open House can use these details to arrange and update this viewing.</label></fieldset><button className="primary" disabled={busy}>{busy?'Requesting…':uncertain?'Retry same viewing request ↗':'Request this time ↗'}</button><p role="status">{message}</p>{uncertain&&<a href="/account">Check your viewing requests ↗</a>}{signIn&&<a href={listingId?propertySignInHref(listingId,'viewing'):'/sign-in'}>Sign in or create an account ↗</a>}</form>}</section>;
}
