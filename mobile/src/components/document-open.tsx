import {useEffect,useRef,useState} from 'react';
import {Pressable,Text,View} from 'react-native';
import * as Linking from 'expo-linking';
import {applicationDocumentDownload} from '../lib/application-documents';
import {supabase} from '../lib/supabase';
import {styles} from './styles';
export function DocumentOpen({owner,application,id}:{owner:string;application:string;id:string}){
 const [busy,setBusy]=useState(false),[message,setMessage]=useState('');const active=useRef(false),mounted=useRef(true);
 useEffect(()=>{mounted.current=true;return()=>{mounted.current=false;};},[]);
 async function open(){if(active.current||!mounted.current||!supabase)return;active.current=true;setBusy(true);setMessage('');try{const url=await applicationDocumentDownload(supabase,owner,application,id);if(!mounted.current)return;await Linking.openURL(url);if(mounted.current)setMessage('The private document link was handed to your device. If it expires before opening, try again for a fresh link.');}catch{if(mounted.current)setMessage('Unable to open this document. Check your connection and try again.');}finally{active.current=false;if(mounted.current)setBusy(false);}}
 return <View style={{gap:12}}><Pressable accessibilityRole="button" disabled={busy} accessibilityState={{disabled:busy}} onPress={()=>void open()} style={styles.button}><Text style={styles.buttonText}>{busy?'Preparing…':'Open private document'}</Text></Pressable>{!!message&&<Text style={styles.body}>{message}</Text>}<Text style={styles.body}>This opens a private link in your device’s browser. Treat any downloaded copy as confidential.</Text></View>;
}
