import {useEffect,useRef,useState} from 'react';
import {Pressable,Text,View} from 'react-native';
import * as Linking from 'expo-linking';
import {managerEvidenceDownload} from '../lib/manager-evidence-download';
import {supabase} from '../lib/supabase';
import {styles} from './styles';
export function ManagerEvidenceOpen({owner,work,offer,report,id}:{owner:string;work:string;offer:string;report:string;id:string}){
 const [busy,setBusy]=useState(false),[message,setMessage]=useState('');const active=useRef(false),mounted=useRef(true);
 useEffect(()=>{mounted.current=true;return()=>{mounted.current=false;};},[]);
 async function open(){if(active.current||!mounted.current||!supabase)return;active.current=true;setBusy(true);setMessage('');try{const url=await managerEvidenceDownload(supabase,owner,work,offer,report,id);if(!mounted.current)return;await Linking.openURL(url);if(mounted.current)setMessage('The private evidence link was handed to your device. If it expires before opening, try again for a fresh link.');}catch{if(mounted.current)setMessage('Unable to open this evidence. Check your connection and try again.');}finally{active.current=false;if(mounted.current)setBusy(false);}}
 return <View style={{gap:12}}><Pressable accessibilityRole="button" disabled={busy} accessibilityState={{disabled:busy}} onPress={()=>void open()} style={styles.button}><Text style={styles.buttonText}>{busy?'Preparing…':'Open private evidence'}</Text></Pressable>{!!message&&<Text style={styles.body}>{message}</Text>}<Text style={styles.body}>This opens a private link in your device’s browser. Treat any downloaded copy as confidential.</Text></View>;
}
