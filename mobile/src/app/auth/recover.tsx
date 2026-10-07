import {useEffect,useRef,useState} from 'react';
import {Link,useLocalSearchParams} from 'expo-router';
import {ScrollView,Text,TextInput,Pressable} from 'react-native';
import {supabase} from '../../lib/supabase';
import {confirmNativeRecovery,updateRecoveredPassword} from '../../lib/account-access';
import {styles} from '../../components/styles';
export default function Recovery(){const params=useLocalSearchParams<{code?:string|string[];error?:string|string[]}>();const code=typeof params.code==='string'?params.code:'';return <Attempt key={code+String(!!params.error)} code={code} invalid={!!params.error}/>;}
function Attempt({code,invalid}:{code:string;invalid:boolean}){
 const [owner,setOwner]=useState(''),[password,setPassword]=useState(''),[confirmation,setConfirmation]=useState(''),[busy,setBusy]=useState(false),[done,setDone]=useState(false),[uncertain,setUncertain]=useState(false),[message,setMessage]=useState(!supabase||!code||invalid?'Recovery link unavailable. Request a new email.':'Verifying recovery…');
 const mounted=useRef(true),active=useRef(false),attempted=useRef(false),frozen=useRef<string|null>(null),completed=useRef(false);
 useEffect(()=>{mounted.current=true;return()=>{mounted.current=false;frozen.current=null;};},[]);
 useEffect(()=>{if(attempted.current||!code||invalid||!supabase)return;attempted.current=true;void(async()=>{try{const id=await confirmNativeRecovery(supabase,code);if(mounted.current){setOwner(id);setMessage('Choose and confirm a new password.');}}catch{if(mounted.current)setMessage('Recovery could not be verified. Request a new email and open it on the initiating device.');}})();},[code,invalid]);
 async function save(){if(active.current||completed.current||!mounted.current||!owner||!supabase)return;
  if(frozen.current===null&&(password!==confirmation||password.length<12||password.length>1024)){setMessage('Use matching passwords of at least 12 characters.');return;}
  active.current=true;setBusy(true);frozen.current??=password;
  try{await updateRecoveredPassword(supabase,owner,frozen.current);if(!mounted.current)return;completed.current=true;setDone(true);setPassword('');setConfirmation('');frozen.current=null;setMessage('The password update was accepted. Sign in using your new password.');const result=await supabase.auth.signOut({scope:'local'});if(mounted.current&&result.error)setMessage('The password update was accepted, but local sign-out could not be confirmed. Sign out before signing in again.');}
  catch{if(mounted.current){setUncertain(true);setMessage(completed.current?'The password update was accepted, but local sign-out could not be confirmed. Sign out before signing in again.':'Password update could not be confirmed. Retry this same password or return to sign-in to check access.');}}
  finally{active.current=false;if(mounted.current)setBusy(false);}
 }
 return <ScrollView keyboardShouldPersistTaps="handled" contentContainerStyle={styles.page}><Text style={styles.title}>Recover your account.</Text><Text accessibilityLiveRegion="polite" style={styles.body}>{message}</Text>{!!owner&&!done&&<><TextInput accessibilityLabel="New password" textContentType="newPassword" secureTextEntry editable={!busy&&!uncertain} value={password} onChangeText={setPassword} style={styles.input}/><TextInput accessibilityLabel="Confirm new password" secureTextEntry editable={!busy&&!uncertain} value={confirmation} onChangeText={setConfirmation} style={styles.input}/><Pressable accessibilityRole="button" disabled={busy} onPress={()=>void save()} style={styles.button}><Text style={styles.buttonText}>{busy?'Updating…':uncertain?'Retry same password update':'Update password'}</Text></Pressable></>}<Link href="/sign-in" style={styles.link}>Return to sign-in →</Link></ScrollView>;
}
