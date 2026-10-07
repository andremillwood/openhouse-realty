'use client';
import {useState} from 'react';
import {useRouter} from 'next/navigation';
import {sellerStageLabel} from '@/lib/sellers/validation';
export function SellerStages({id,status}:{id:string;status:string}){
 const router=useRouter();const [next,setNext]=useState(''),[reason,setReason]=useState(''),[message,setMessage]=useState(''),[busy,setBusy]=useState(false);
 const forward=({new:'contacted',contacted:'market_review',market_review:'proposal'} as Record<string,string>)[status];
 if(['listed','closed','lost'].includes(status))return <p>This request has reached {sellerStageLabel(status).toLowerCase()}.</p>;
 async function submit(event:React.FormEvent<HTMLFormElement>){event.preventDefault();setBusy(true);setMessage('');try{const response=await fetch('/api/staff/sellers',{method:'PATCH',headers:{'Content-Type':'application/json'},body:JSON.stringify({id,status:next,expected_status:status,reason})});const result=await response.json();if(!response.ok){if(response.status===409)router.refresh();throw new Error(result.error);}setMessage('Follow-up stage recorded.');router.refresh();}catch(error){setMessage(error instanceof Error?error.message:'Unable to update.');}finally{setBusy(false);}}
 return <form onSubmit={submit}><label>Next stage<select required value={next} disabled={busy} onChange={event=>setNext(event.target.value)}><option value="" disabled>Choose next step</option>{forward&&<option value={forward}>{sellerStageLabel(forward)}</option>}<option value="closed">Close request</option><option value="lost">Not proceeding</option></select></label><label>Follow-up reason (shared with the seller)<textarea required minLength={5} maxLength={500} disabled={busy} value={reason} onChange={event=>setReason(event.target.value)}/></label><button disabled={busy||!next}>Record follow-up</button><p role="status">{message}</p>{status==='proposal'&&<p>Publication handoff is the next step after an approved proposal. This request does not create or publish a listing automatically.</p>}</form>;
}
