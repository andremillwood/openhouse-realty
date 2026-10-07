import {useEffect,useRef,useState} from 'react';
import {Platform,Pressable,Text,View} from 'react-native';
import * as DocumentPicker from 'expo-document-picker';
import {File} from 'expo-file-system';
import {randomUUID} from 'expo-crypto';
import {documentSignature} from '../../../lib/documents/files';
import {invoiceUploadAttempt,reserveInvoiceUpload,uploadInvoiceBytes,finishInvoiceUpload,type InvoiceUploadAttempt,type InvoiceUploadReservation} from '../lib/finance-invoice-upload';
import {supabase} from '../lib/supabase';
import {styles} from './styles';
type Pending={attempt:InvoiceUploadAttempt;bytes:ArrayBuffer;reservation?:InvoiceUploadReservation;sent:boolean};
export function FinanceInvoiceUpload({owner,invoice,onRefresh}:{owner:string;invoice:string;onRefresh:()=>void}){
 const [kind,setKind]=useState<'invoice'|'supporting'>('invoice');
 const [pending,setPending]=useState<Pending|null>(null),[busy,setBusy]=useState(false),[message,setMessage]=useState(''),[done,setDone]=useState(false);
 const active=useRef(false),mounted=useRef(true),current=useRef<Pending|null>(null),complete=useRef(false);
 useEffect(()=>{mounted.current=true;return()=>{mounted.current=false;current.current=null;};},[]);
 const base=process.env.EXPO_PUBLIC_APP_URL||'';
 async function choose(){if(active.current||current.current||!mounted.current||!base)return;active.current=true;setBusy(true);try{
  const result=await DocumentPicker.getDocumentAsync({type:['application/pdf','image/jpeg','image/png'],multiple:false,copyToCacheDirectory:true,base64:false});
  if(!mounted.current||result.canceled)return;
  const asset=result.assets[0];if(!asset||!asset.size||asset.size>8*1024*1024)throw Error();
  const attempt=invoiceUploadAttempt(invoice,randomUUID(),kind,asset.name,asset.mimeType||'',asset.size);
  let bytes:ArrayBuffer;
  if(Platform.OS==='web'){if(!asset.file)throw Error();bytes=await asset.file.arrayBuffer();}
  else{const cached=new File(asset.uri);try{bytes=await cached.arrayBuffer();}finally{try{cached.delete();}catch{/* OS cache cleanup can complete later. */}}}
  if(bytes.byteLength!==attempt.size)throw Error();documentSignature(new Uint8Array(bytes),attempt.mime_type);
  if(!mounted.current)return;const next={attempt,bytes,sent:false};current.current=next;setPending(next);setDone(false);complete.current=false;setMessage('File selected. Confirm upload to share it with authorized invoice reviewers.');
 }catch{if(mounted.current)setMessage('Choose a valid PDF, JPEG or PNG up to 8 MB.');}finally{active.current=false;if(mounted.current)setBusy(false);}}
 async function send(finalizeOnly=false){const p=current.current;if(active.current||complete.current||!mounted.current||!p||!supabase)return;active.current=true;setBusy(true);
  try{if(!p.reservation){p.reservation=await reserveInvoiceUpload(supabase,owner,base,p.attempt);if(mounted.current)setPending({...p});}
   if(!mounted.current)return;
   if(p.reservation.state!=='uploaded'){
    if(!finalizeOnly){p.sent=true;if(mounted.current)setPending({...p});await uploadInvoiceBytes(supabase,owner,p.reservation,p.attempt,p.bytes);}
    if(!mounted.current)return;
    await finishInvoiceUpload(supabase,owner,base,invoice,p.reservation.id);
   }
   if(!mounted.current)return;complete.current=true;current.current=null;setPending(null);setDone(true);setMessage('Document certified as uploaded. Independent invoice review and payment are separate steps.');
  }catch{if(mounted.current)setMessage('Upload could not be confirmed. Keep this request. If storage was attempted, check certification first; retrying storage never overwrites a file.');}
  finally{active.current=false;if(mounted.current)setBusy(false);}
 }
 return <View style={styles.card}><Text style={styles.heading}>Add an invoice document</Text><Text style={styles.body}>PDF, JPEG or PNG · up to 8 MB. Your file is private to authorized invoice review.</Text>{!base?<Text style={styles.body}>Mobile invoice upload is awaiting the secure application connection.</Text>:<>{!pending&&!done&&<>{(['invoice','supporting'] as const).map(value=><Pressable key={value} accessibilityRole="radio" accessibilityState={{selected:kind===value,disabled:busy}} disabled={busy} onPress={()=>{if(!active.current&&!current.current)setKind(value);}}><Text style={styles.link}>{value==='invoice'?'Vendor invoice':'Supporting document'}</Text></Pressable>)}<Pressable accessibilityRole="button" disabled={busy} onPress={()=>void choose()}><Text style={styles.link}>Choose document</Text></Pressable></>}{pending&&<><Text style={styles.body}>{pending.attempt.file_name}</Text><Text style={styles.body}>{pending.attempt.kind==='invoice'?'Vendor invoice':'Supporting document'} · {pending.attempt.size.toLocaleString()} bytes</Text><Text selectable style={styles.body}>Request: {pending.attempt.request_id}</Text>{pending.sent&&<Pressable accessibilityRole="button" disabled={busy} onPress={()=>void send(true)}><Text style={styles.link}>Check and finish this upload</Text></Pressable>}<Pressable accessibilityRole="button" disabled={busy} onPress={()=>void send()}><Text style={styles.link}>{pending.sent?'Retry same file storage upload':'Confirm upload of this file'}</Text></Pressable></>}{done&&<Pressable accessibilityRole="button" onPress={onRefresh}><Text style={styles.link}>Refresh invoice documents</Text></Pressable>}</>}{busy&&<Text style={styles.body}>Working…</Text>}{!!message&&<Text accessibilityRole="text" accessibilityLiveRegion="polite" style={styles.body}>{message}</Text>}</View>;
}
