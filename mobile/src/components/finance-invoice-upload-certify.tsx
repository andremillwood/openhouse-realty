import {useEffect,useRef,useState} from 'react';
import {Pressable,Text,View} from 'react-native';
import {finishInvoiceUpload} from '../lib/finance-invoice-upload';
import {supabase} from '../lib/supabase';
import {styles} from './styles';
export function InvoiceUploadCertify({owner,invoice,id,onRefresh}:{owner:string;invoice:string;id:string;onRefresh:()=>void}){
 const [busy,setBusy]=useState(false),[message,setMessage]=useState(''),[done,setDone]=useState(false);const active=useRef(false),mounted=useRef(true),complete=useRef(false);
 useEffect(()=>{mounted.current=true;return()=>{mounted.current=false;};},[]);
 const base=process.env.EXPO_PUBLIC_APP_URL||'';
 async function check(){if(active.current||complete.current||!mounted.current||!supabase||!base)return;active.current=true;setBusy(true);try{await finishInvoiceUpload(supabase,owner,base,invoice,id);if(!mounted.current)return;complete.current=true;setDone(true);setMessage('Invoice document certified as uploaded. Independent invoice approval remains separate. Refresh file records to view it.');}catch{if(mounted.current)setMessage('Certification could not be confirmed. The file may be missing, expired or invalid, or the connection unavailable. Retry this same reservation or withdraw it.');}finally{active.current=false;if(mounted.current)setBusy(false);}}
 return <View style={{gap:12}}>{base?!done&&<Pressable accessibilityRole="button" disabled={busy} onPress={()=>void check()}><Text style={styles.link}>{busy?'Checking…':'Check stored file and finish upload'}</Text></Pressable>:<Text style={styles.body}>Certification awaits the secure application connection.</Text>}{!!message&&<Text accessibilityLiveRegion="polite" style={styles.body}>{message}</Text>}{done&&<Pressable accessibilityRole="button" onPress={onRefresh}><Text style={styles.link}>Refresh reservation records</Text></Pressable>}</View>;
}
