import {useEffect,useRef,useState} from 'react';
import {Platform,Pressable,Text,View} from 'react-native';
import * as DocumentPicker from 'expo-document-picker';
import {File} from 'expo-file-system';
import {randomUUID} from 'expo-crypto';
import {documentSignature} from '../../../lib/documents/files';
import {evidenceAttempt,reserveEvidence,uploadEvidenceBytes,finishEvidence,type EvidenceAttempt,type EvidenceReservation} from '../lib/contractor-evidence-upload';
import {supabase} from '../lib/supabase';
import {styles} from './styles';
type Pending={attempt:EvidenceAttempt;bytes:ArrayBuffer;reservation?:EvidenceReservation;sent:boolean};
export function EvidenceUpload({owner,offer,onRefresh}:{owner:string;offer:string;onRefresh:()=>void}){
 const [pending,setPending]=useState<Pending|null>(null),[busy,setBusy]=useState(false),[message,setMessage]=useState(''),[done,setDone]=useState(false);
 const active=useRef(false),mounted=useRef(true),current=useRef<Pending|null>(null),complete=useRef(false);
 useEffect(()=>{mounted.current=true;return()=>{mounted.current=false;current.current=null;};},[]);
 const base=process.env.EXPO_PUBLIC_APP_URL||'';
 async function choose(){if(active.current||current.current||!mounted.current||!base)return;active.current=true;setBusy(true);try{
  const result=await DocumentPicker.getDocumentAsync({type:['application/pdf','image/jpeg','image/png'],multiple:false,copyToCacheDirectory:true,base64:false});
  if(!mounted.current||result.canceled)return;
  const asset=result.assets[0];if(!asset||!asset.size||asset.size>8*1024*1024)throw Error();
  const attempt=evidenceAttempt(offer,randomUUID(),asset.name,asset.mimeType||'',asset.size);
  let bytes:ArrayBuffer;
  if(Platform.OS==='web'){if(!asset.file)throw Error();bytes=await asset.file.arrayBuffer();}
  else{const cached=new File(asset.uri);try{bytes=await cached.arrayBuffer();}finally{try{cached.delete();}catch{/* OS cache cleanup can complete later. */}}}
  if(bytes.byteLength!==attempt.size)throw Error();documentSignature(new Uint8Array(bytes),attempt.mime_type);
  if(!mounted.current)return;const next={attempt,bytes,sent:false};current.current=next;setPending(next);setDone(false);complete.current=false;setMessage('File selected. Confirm upload to share it with the property team.');
 }catch{if(mounted.current)setMessage('Choose a valid PDF, JPEG or PNG up to 8 MB.');}finally{active.current=false;if(mounted.current)setBusy(false);}}
 async function send(finalizeOnly=false){const p=current.current;if(active.current||complete.current||!mounted.current||!p||!supabase)return;active.current=true;setBusy(true);
  try{if(!p.reservation){p.reservation=await reserveEvidence(supabase,owner,base,p.attempt);if(mounted.current)setPending({...p});}
   if(!mounted.current)return;
   if(p.reservation.state!=='uploaded'){
    if(!finalizeOnly){p.sent=true;if(mounted.current)setPending({...p});await uploadEvidenceBytes(supabase,owner,p.reservation,p.attempt,p.bytes);}
    if(!mounted.current)return;
    await finishEvidence(supabase,owner,base,offer,p.reservation.id);
   }
   if(!mounted.current)return;complete.current=true;current.current=null;setPending(null);setDone(true);setMessage('Evidence recorded as uploaded. Team approval is a separate review.');
  }catch{if(mounted.current)setMessage('Upload could not be confirmed. Keep this request. If storage was attempted, check certification first; retrying storage never overwrites a file.');}
  finally{active.current=false;if(mounted.current)setBusy(false);}
 }
 return <View style={styles.card}><Text style={styles.heading}>Add a private evidence</Text><Text style={styles.body}>PDF, JPEG or PNG · up to 8 MB. Your file is private to authorized assignment review.</Text>{!base?<Text style={styles.body}>Mobile evidence upload is awaiting the secure application connection.</Text>:<>{!pending&&!done&&<><Pressable accessibilityRole="button" disabled={busy} onPress={()=>void choose()}><Text style={styles.link}>Choose evidence</Text></Pressable></>}{pending&&<><Text style={styles.body}>{pending.attempt.file_name}</Text><Text selectable style={styles.body}>Request: {pending.attempt.request_id}</Text>{pending.sent&&<Pressable accessibilityRole="button" disabled={busy} onPress={()=>void send(true)}><Text style={styles.link}>Check and finish this upload</Text></Pressable>}<Pressable accessibilityRole="button" disabled={busy} onPress={()=>void send()}><Text style={styles.link}>{pending.sent?'Retry same file storage upload':'Confirm upload of this file'}</Text></Pressable></>}{done&&<Pressable accessibilityRole="button" onPress={onRefresh}><Text style={styles.link}>Refresh evidence records</Text></Pressable>}</>}{busy&&<Text style={styles.body}>Working…</Text>}{!!message&&<Text accessibilityRole="text" accessibilityLiveRegion="polite" style={styles.body}>{message}</Text>}</View>;
}
