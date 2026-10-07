import {useEffect,useRef,useState} from 'react';
import {Pressable,Text,TextInput,View} from 'react-native';
import {supabase} from '../lib/supabase';
import {resendNativeConfirmation} from '../lib/account-access';
import {styles} from './styles';
export function ConfirmationResend(){
 const [email,setEmail]=useState(''),[busy,setBusy]=useState(false),[message,setMessage]=useState(''),[waiting,setWaiting]=useState(false);const active=useRef(false),mounted=useRef(true),next=useRef(0);
 useEffect(()=>{mounted.current=true;return()=>{mounted.current=false;};},[]);
 async function submit(){if(active.current||!mounted.current||!supabase||Date.now()<next.current)return;active.current=true;setBusy(true);next.current=Date.now()+60000;setWaiting(true);
  try{await resendNativeConfirmation(supabase,email);if(mounted.current)setMessage('If this email has an unconfirmed account, check your inbox and spam folder. Open the newest link on this device. This does not confirm email delivery.');}
  catch(error){if(mounted.current)setMessage(error instanceof Error&&['Enter a valid email.','Sign out before requesting confirmation.'].includes(error.message)?error.message:'The request could not be confirmed. Check your email and wait before retrying.');}
  finally{active.current=false;if(mounted.current)setBusy(false);}
 }
 // Cooldown survives rerenders; server rate limits still apply across app restarts.
 useEffect(()=>{if(!waiting)return;const timer=setTimeout(()=>{if(mounted.current)setWaiting(false);},Math.max(0,next.current-Date.now()));return()=>clearTimeout(timer);},[waiting]);
 return <View style={styles.card}><Text style={styles.heading}>Need another confirmation?</Text><Text style={styles.body}>Requesting a new link replaces the previous confirmation attempt. Use the latest email on this device.</Text><TextInput accessibilityLabel="Confirmation email" autoCapitalize="none" autoCorrect={false} keyboardType="email-address" value={email} onChangeText={setEmail} editable={!busy&&!waiting} style={styles.input}/><Pressable accessibilityRole="button" disabled={busy||waiting||!supabase} onPress={()=>void submit()}><Text style={styles.link}>{busy?'Requesting…':waiting?'Wait a minute before another request':'Request confirmation email'}</Text></Pressable>{!!message&&<Text accessibilityLiveRegion="polite" style={styles.body}>{message}</Text>}</View>;
}
