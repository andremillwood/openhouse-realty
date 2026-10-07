export const chequeActions=['receive','record_deposit','confirm_clear','record_return','cancel'] as const;
/** Custody requests never authorize ledger entries or derive bank confirmation from a client status. */
export function chequeInput(value:unknown){
 if(!value||typeof value!=='object'||Array.isArray(value))throw new Error('Invalid cheque request.');
 const input=value as Record<string,unknown>,uuid=/^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
 const validId=(v:unknown):v is string=>typeof v==='string'&&uuid.test(v);
 const text=(v:unknown,min:number,max:number)=>typeof v==='string'&&v.trim().length>=min&&v.length<=max&&!/[\u0000-\u001f\u007f]/.test(v);
 if(!validId(input.request_id)||typeof input.action!=='string'||!chequeActions.includes(input.action as typeof chequeActions[number]))throw new Error('Choose an available cheque action.');
 if(typeof input.version!=='number'||!Number.isInteger(input.version)||input.version<0||input.version>=2147483647)throw new Error('Refresh the cheque revision.');
 if(typeof input.reason!=='string'||input.reason.trim().length<5||input.reason.length>500||input.approved!==true)throw new Error('Record a reason and explicit custody approval.');
 let id:string|null=null,property:string|null=null,payer:string|null=null,bank:string|null=null,reference:string|null=null,amount:number|null=null,evidence:string|null=null,bankReference:string|null=null;
 if(input.action==='receive'){
  if(input.cheque_id!=null||input.version!==0)throw new Error('New cheque receipt required.');
  if(!validId(input.property_id)||!text(input.payer_name,2,160)||!text(input.bank_name,2,160)||!text(input.cheque_reference,1,80))throw new Error('Provide the property, payer, bank and cheque reference.');
  if(typeof input.amount_minor!=='number'||!Number.isSafeInteger(input.amount_minor)||input.amount_minor<1||input.amount_minor>99999999999999)throw new Error('Provide a positive whole-minor-unit JMD amount.');
  if(input.evidence_id!=null||input.bank_reference!=null)throw new Error('Record bank actions after the receipt is created.');
  property=input.property_id;payer=(input.payer_name as string).trim();bank=(input.bank_name as string).trim();reference=(input.cheque_reference as string).trim();amount=input.amount_minor;
 }else{
  if(!validId(input.cheque_id)||input.version<1)throw new Error('Current cheque reference and revision required.');id=input.cheque_id;
  for(const key of ['property_id','payer_name','bank_name','cheque_reference','amount_minor'])if(input[key]!=null)throw new Error('Received cheque details cannot change.');
  if(input.action==='cancel'){
   if(input.evidence_id!=null||input.bank_reference!=null)throw new Error('Cancellation cannot record a bank event.');
  }else{
   if(!validId(input.evidence_id)||!text(input.bank_reference,3,120))throw new Error('Select certified bank evidence and its reference.');
   evidence=input.evidence_id;bankReference=(input.bank_reference as string).trim();
  }
 }
 return {p_request_id:input.request_id,p_action:input.action as typeof chequeActions[number],p_cheque_id:id,p_expected_version:input.version,p_property_id:property,p_payer_name:payer,p_bank_name:bank,p_cheque_reference:reference,p_amount_minor:amount,p_evidence_id:evidence,p_bank_reference:bankReference,p_reason:input.reason.trim(),p_approved:true};
}
