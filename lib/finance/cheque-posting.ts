export function chequePostingInput(value:unknown){
 if(!value||typeof value!=='object'||Array.isArray(value))throw new Error('Invalid cheque posting request.');
 const input=value as Record<string,unknown>,uuid=/^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
 const reference=(value:unknown):value is string=>typeof value==='string'&&uuid.test(value);
 if(!reference(input.request_id)||!reference(input.cheque_id)||!reference(input.debit_account_id)||!reference(input.credit_account_id)||input.debit_account_id===input.credit_account_id)throw new Error('Select distinct approved debit and credit accounts for this cheque.');
 if(typeof input.version!=='number'||!Number.isInteger(input.version)||input.version<3||input.version>=2147483647)throw new Error('Refresh the cleared cheque revision.');
 if(typeof input.reason!=='string'||input.reason.trim().length<5||input.reason.length>500||input.approved!==true)throw new Error('Record an accounting reason and explicit posting approval.');
 return {p_request_id:input.request_id,p_cheque_id:input.cheque_id,p_expected_version:input.version,p_debit_account_id:input.debit_account_id,p_credit_account_id:input.credit_account_id,p_reason:input.reason.trim(),p_approved:true};
}
