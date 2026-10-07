'use client';
import {useState} from 'react';
import {useRouter} from 'next/navigation';
export function ApplicationActions({id,status,version,isOwner,isReviewer}:{id:string;status:string;version:number;isOwner:boolean;isReviewer:boolean}){
 const router=useRouter();const [action,setAction]=useState(''),[message,setMessage]=useState(''),[notice,setNotice]=useState(''),[busy,setBusy]=useState(false),[requestId,setRequestId]=useState('');
 const actions:{value:string;label:string}[]=[];
 if(isOwner&&status==='needs_info')actions.push({value:'reply',label:'Reply and resubmit'});
 if(isOwner&&['submitted','under_review','needs_info','approved'].includes(status))actions.push({value:'withdraw',label:'Withdraw application'});
 if(isReviewer&&status==='submitted')actions.push({value:'start_review',label:'Start review'});
 if(isReviewer&&status==='under_review')actions.push({value:'request_info',label:'Request more information'});
 if(isReviewer&&['under_review','needs_info'].includes(status))actions.push({value:'reject',label:'Record a decision not to proceed'});
 if(!actions.length)return <p>There are no available review actions at this stage.</p>;
 async function submit(event:React.FormEvent<HTMLFormElement>){event.preventDefault();const retry=requestId||crypto.randomUUID();setRequestId(retry);setBusy(true);setNotice('');try{const response=await fetch('/api/applications',{method:'PATCH',headers:{'Content-Type':'application/json'},body:JSON.stringify({id,request_id:retry,version,action,message})});const result=await response.json();if(!response.ok){if(response.status===409)router.refresh();throw new Error(result.error);}setNotice('Application history updated.');router.refresh();}catch(error){setNotice(error instanceof Error?error.message:'Unable to update. Retry without changing your response.');}finally{setBusy(false);}}
 return <form onSubmit={submit}><label>Next step<select required disabled={busy} value={action} onChange={event=>{setAction(event.target.value);setRequestId('');}}><option value="" disabled>Choose an action</option>{actions.map(row=><option key={row.value} value={row.value}>{row.label}</option>)}</select></label><label>{isOwner?'Reply or withdrawal reason':'Shared review or decision reason'}<textarea required minLength={5} maxLength={2000} disabled={busy} value={message} onChange={event=>{setMessage(event.target.value);setRequestId('');}}/></label><button disabled={busy||!action}>{busy?'Recording…':'Record next step'}</button><p role="status">{notice}</p></form>;
}
