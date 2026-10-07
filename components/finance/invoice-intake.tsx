'use client';
import {useRef,useState,type FormEvent} from 'react';
import {invoiceInput} from '@/lib/finance/invoice-validation';
import {jmdMinor} from '@/lib/finance/money';
import {DimensionPicker} from '@/components/finance/dimension-picker';
import {InvoiceWorkPicker} from '@/components/finance/invoice-work-picker';
export function InvoiceIntake({property,workOrder,allowPropertySearch=false}:{property?:{id:string;name:string};workOrder?:{id:string;title:string};allowPropertySearch?:boolean}) {
 const [selectedProperty,setSelectedProperty]=useState(''),[selectedWork,setSelectedWork]=useState('');
 const [busy,setBusy]=useState(false),[message,setMessage]=useState('');const retry=useRef<{payload:string;id:string}|null>(null);
 async function submit(event:FormEvent<HTMLFormElement>) {
  event.preventDefault();const form=new FormData(event.currentTarget);setBusy(true);setMessage('');
  try {
   const input={action:'submit',invoice_id:null,version:0,property_id:property?.id||(allowPropertySearch?selectedProperty||null:null),work_order_id:workOrder?.id||(allowPropertySearch?selectedWork||null:null),vendor_name:String(form.get('vendor_name')||''),invoice_number:String(form.get('invoice_number')||''),amount_minor:jmdMinor(String(form.get('amount')||'')),reason:String(form.get('reason')||''),approved:form.get('approved')==='on'};
   const payload=JSON.stringify(input);if(retry.current?.payload!==payload)retry.current={payload,id:crypto.randomUUID()};const body={...input,request_id:retry.current.id};invoiceInput(body);
   const response=await fetch('/api/staff/invoices',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify(body)});const result=await response.json();
   if(!response.ok){if(response.status<500)retry.current=null;throw new Error(result.error||'Unable to submit invoice.');}
   window.location.assign(`/staff/finance/invoices/${result.id}`);
  }catch(error){setMessage(error instanceof Error?error.message:'Unable to submit invoice. Retry the same request.');}finally{setBusy(false);}
 }
 return <form className="staff-editor" onSubmit={submit}><fieldset disabled={busy}><legend>Submit a vendor invoice</legend><p>{property?`Property: ${property.name}`:selectedProperty?'Invoice allocated to the selected managed property.':'Organization invoice without a property allocation.'}{workOrder&&` · Work order: ${workOrder.title}`}</p><p>Submitted details are fixed. A separate finance reviewer and approver must review this invoice. Submission does not create a payment or ledger entry.</p><>{!property&&allowPropertySearch&&<DimensionPicker kind="property" value={selectedProperty} onChange={id=>{setSelectedProperty(id);setSelectedWork('');}}/>}</>{!workOrder&&allowPropertySearch&&<InvoiceWorkPicker key={property?.id||selectedProperty} propertyId={property?.id||selectedProperty} value={selectedWork} onChange={setSelectedWork}/>}<label>Approved vendor name<input name="vendor_name" required minLength={2} maxLength={160}/></label><label>Invoice number<input name="invoice_number" required maxLength={80}/></label><label>Invoice amount (JMD)<input name="amount" inputMode="decimal" required maxLength={15}/><small>Use up to two decimal places, without commas.</small></label><label>Evidence / submission reason<textarea name="reason" required minLength={5} maxLength={500}/></label><label><input type="checkbox" name="approved" required/> I checked the vendor, invoice number, amount and allocation against the invoice.</label><button className="primary">{busy?'Submitting…':'Submit for independent review'}</button></fieldset><p role="status">{message}</p></form>;
}
