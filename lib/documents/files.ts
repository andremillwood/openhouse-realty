export const DOCUMENT_BUCKET='application-documents';
export const MAX_DOCUMENT_BYTES=8*1024*1024;
export const documentKinds=['identity','income','reference','other'] as const;
export function documentFile(name:unknown,mime:unknown,size:unknown){
 if(typeof name!=='string'||!name.trim()||name.length>160||/[\x00-\x1f\x7f/\\]/.test(name)||typeof mime!=='string'||!['application/pdf','image/jpeg','image/png'].includes(mime)||typeof size!=='number'||!Number.isInteger(size)||size<1||size>MAX_DOCUMENT_BYTES)throw new Error('Choose a PDF, JPEG or PNG up to 8 MB with a simple filename.');
 return {name:name.trim(),mime,size};
}
/** Basic file-format screening; authenticity belongs to reviewer verification. */
export function documentSignature(bytes:Uint8Array,mime:string){
 if(bytes.length<8||bytes.length>MAX_DOCUMENT_BYTES)throw new Error('Invalid document size.');
 const ascii=(part:Uint8Array)=>new TextDecoder('latin1').decode(part);
 const pdf=mime==='application/pdf'&&ascii(bytes.slice(0,5))==='%PDF-'&&ascii(bytes.slice(-2048)).includes('%%EOF');
 const jpeg=mime==='image/jpeg'&&bytes[0]===255&&bytes[1]===216&&bytes[2]===255&&bytes.at(-2)===255&&bytes.at(-1)===217;
 const png=mime==='image/png'&&[137,80,78,71,13,10,26,10].every((value,index)=>bytes[index]===value)&&bytes.length>=45&&ascii(bytes.slice(12,16))==='IHDR'&&ascii(bytes.slice(-8,-4))==='IEND';
 if(!pdf&&!jpeg&&!png)throw new Error('The uploaded file does not match its stated format.');
 if(png){const view=new DataView(bytes.buffer,bytes.byteOffset,bytes.byteLength);const width=view.getUint32(16),height=view.getUint32(20);if(!width||!height||width>10000||height>10000)throw new Error('Image dimensions are too large or invalid.');}
}
