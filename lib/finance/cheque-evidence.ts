import {documentFile} from '@/lib/documents/files';
export const CHEQUE_EVIDENCE_BUCKET='cheque-bank-evidence';
export const chequeEvidenceKinds=['deposit','clearance','return'] as const;
/** Certification hashes, actor identity and object paths are never accepted from clients. */
export function chequeEvidenceInput(value:unknown) {
 if(!value||typeof value!=='object'||Array.isArray(value))throw new Error('Invalid cheque bank evidence request.');
 const input=value as Record<string,unknown>,uuid=/^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
 const id=(key:string)=>{const value=input[key];if(typeof value!=='string'||!uuid.test(value))throw new Error('Check the cheque bank evidence reference.');return value;};
 if(input.action==='reserve') {
  const file=documentFile(input.file_name,input.mime_type,input.size);
  if(typeof input.kind!=='string'||!chequeEvidenceKinds.includes(input.kind as 'deposit'|'clearance'|'return'))throw new Error('Choose deposit, clearance or return evidence.');
  return {action:'reserve' as const,request_id:id('request_id'),cheque_id:id('cheque_id'),kind:input.kind as 'deposit'|'clearance'|'return',file_name:file.name,mime_type:file.mime,size:file.size};
 }
 if(input.action==='finish'||input.action==='withdraw'||input.action==='download')return {action:input.action,id:id('id')};
 throw new Error('Choose an available evidence action.');
}
