'use client';
import {useRef,useState,type FormEvent} from 'react';
import {useRouter} from 'next/navigation';
import {uuidPattern} from '@/lib/enquiries/validation';
import type {LeaseReviewAction} from '@/lib/leases/review';
export function LeaseSummaryReview({releaseId,revision,role,latestAction,current}:{releaseId:string;revision:number;role:'applicant'|'staff';latestAction:LeaseReviewAction|null;current:boolean}){
 const router=useRouter();const active=useRef(false),completed=useRef(false),attempt=useRef<{request_id:string;action:LeaseReviewAction;message:string}|null>(null);
 const [action,setAction]=useState<LeaseReviewAction>(role==='staff'?'answer':latestAction==='reviewed'?'question':'reviewed'),[busy,setBusy]=useState(false),[uncertain,setUncertain]=useState(false),[notice,setNotice]=useState('');
 async function submit(event:FormEvent<HTMLFormElement>){event.preventDefault();if(active.current||completed.current)return;
  if(!attempt.current){const form=new FormData(event.currentTarget);if(form.get('acknowledged')!=='on')return;attempt.current={request_id:crypto.randomUUID(),action,message:action==='reviewed'?'':String(form.get('message')||'').trim()};}
  const original=attempt.current;active.current=true;setBusy(true);setNotice('');
  try{const response=await fetch('/api/lease-reviews',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({release_id:releaseId,version:revision,...original,review_only_acknowledged:true})});const result=await response.json();
   if(!response.ok){if(response.status>=500||uncertain){setUncertain(true);setNotice('Response is unconfirmed. Retry unchanged or refresh to check the history.');}else{attempt.current=null;setNotice(response.status===409?'The summary or conversation changed. Refresh before responding.':response.status===429?'Daily response limit reached. Try again later.':'Check your access, message and review-only acknowledgment.');}if(response.status===409)router.refresh();return;}
   if(!result||typeof result.id!=='string'||!uuidPattern.test(result.id)||result.release_id!==releaseId||result.version!==revision+1||result.action!==original.action)throw Error('Unconfirmed response');
   completed.current=true;setUncertain(false);setNotice('Your response is recorded. Refresh to see the latest conversation. This does not sign or accept a lease.');router.refresh();
  }catch{setUncertain(true);setNotice('Response is unconfirmed. Retry unchanged or refresh to check the history.');}finally{active.current=false;setBusy(false);}
 }
 if(!current)return <p>This summary is no longer current. Its recorded discussion remains available; use the current released version for a new response.</p>;
 if(role==='applicant'&&latestAction==='question')return <p>Your question is awaiting a team reply. Refresh to check for a response.</p>;
 if(role==='staff'&&latestAction!=='question')return <p>There is no unanswered applicant question on this version.</p>;
 return <form onSubmit={submit}><h2>{role==='staff'?'Reply to the applicant':'Review this version'}</h2><p>Your response is shared with the applicant and authorized team. Keep internal notes and other people’s personal information out of this message.</p><fieldset disabled={busy||uncertain||completed.current}>{role==='applicant'&&<label>Response<select value={action} onChange={event=>setAction(event.target.value as LeaseReviewAction)}>{latestAction!=='reviewed'&&<option value="reviewed">Record that I reviewed this summary</option>}<option value="question">Ask a question about this summary</option></select></label>}{action!=='reviewed'&&<label>{role==='staff'?'Shared reply':'Your question'}<textarea name="message" required minLength={10} maxLength={2000}/></label>}<label><input type="checkbox" name="acknowledged" required/>I understand this records a review, question or reply only. It does not sign or accept the legal lease, confirm payment or authorize move-in.</label></fieldset><button disabled={busy||completed.current}>{busy?'Saving…':uncertain?'Retry the same response':role==='staff'?'Send shared reply':action==='question'?'Send question':'Record review'}</button><p role="status">{notice}</p></form>;
}
