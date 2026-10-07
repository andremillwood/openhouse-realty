import {documentFile} from '@/lib/documents/files';
export const LEASE_TEMPLATE_BUCKET='lease-template-documents';
export function leaseTemplateDocumentInput(value:unknown){
 if(!value||typeof value!=='object'||Array.isArray(value))throw new Error('Invalid legal document request.');
 const input=value as Record<string,unknown>,uuid=/^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
 const id=(key:string)=>{const v=input[key];if(typeof v!=='string'||!uuid.test(v))throw new Error('Check the legal document reference.');return v;};
 if(input.action==='reserve'){
  const file=documentFile(input.file_name,'application/pdf',input.size);
  return {action:'reserve' as const,template_id:id('template_id'),request_id:id('request_id'),file_name:file.name,size:file.size};
 }
 if(input.action==='finish'||input.action==='withdraw'||input.action==='download')return {action:input.action,id:id('id')};
 throw new Error('Choose an available legal document action.');
}
