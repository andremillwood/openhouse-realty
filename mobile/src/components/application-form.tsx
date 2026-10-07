import {useEffect,useRef,useState} from 'react';
import {ActivityIndicator,Pressable,Text,TextInput,View} from 'react-native';
import {Link} from 'expo-router';
import {randomUUID} from 'expo-crypto';
import {useIdentity} from './identity';
import {styles} from './styles';
import {supabase} from '../lib/supabase';
import {EnquiryFailure} from '../lib/enquiries';
import {applicationAttempt,submitApplication,type ApplicationAttempt} from '../lib/applications';
export function ApplicationForm({listingId}:{listingId:string}){
 const {user,loading,error,refresh}=useIdentity();
 if(loading)return <ActivityIndicator accessibilityLabel="Checking your account"/>;
 if(error)return <View><Text accessibilityRole="alert" style={styles.body}>{error}</Text><Pressable accessibilityRole="button" onPress={()=>void refresh()}><Text style={styles.link}>Check account again</Text></Pressable></View>;
 if(!user)return <Link href="/sign-in" style={styles.link}>Sign in to apply →</Link>;
 return <ApplicationControl key={user.id+':'+listingId} owner={user.id} listingId={listingId}/>;
}
export function ApplicationControl({owner,listingId}:{owner:string;listingId:string}){
 const [name,setName]=useState(''),[phone,setPhone]=useState(''),[message,setMessage]=useState(''),[consent,setConsent]=useState(false);
 const [household,setHousehold]=useState('1'),[moveIn,setMoveIn]=useState('');
 const [busy,setBusy]=useState(false),[uncertain,setUncertain]=useState(false),[notice,setNotice]=useState(''),[confirmed,setConfirmed]=useState(false);
 const active=useRef(false),attempt=useRef<ApplicationAttempt|null>(null),mounted=useRef(true),complete=useRef(false);
 useEffect(()=>{mounted.current=true;return()=>{mounted.current=false;};},[]);
 async function send(){
  if(active.current||complete.current||!mounted.current)return;
  active.current=true;setBusy(true);setNotice('');
  const retrying=attempt.current!==null;
  try{
   if(!supabase)throw new EnquiryFailure('Account connection is unavailable.',false);
   const payload=attempt.current??applicationAttempt({requestId:randomUUID(),listingId,name,phone,message,consent,householdSize:/^\d{1,2}$/.test(household)?Number(household):NaN,moveIn});
   attempt.current=payload;
   const stored=await submitApplication(supabase,owner,payload);
   if(!mounted.current)return;
   complete.current=true;setConfirmed(true);setUncertain(false);setNotice(`Your application is stored. Recorded status: ${stored.status.replaceAll('_',' ')}. Approval is not a signed lease or an activated tenancy.`);
  }catch(error){if(mounted.current){const unknown=retrying||!(error instanceof EnquiryFailure)||error.uncertain;setUncertain(unknown);if(!unknown)attempt.current=null;setNotice(error instanceof EnquiryFailure?error.message:'We could not confirm your application. Retry the same request.');}}
  finally{active.current=false;if(mounted.current)setBusy(false);}
 }
 const locked=busy||uncertain||confirmed;
 return <View style={styles.card}><Text style={styles.heading}>Apply for your next chapter.</Text><Text style={styles.body}>Apply to rent this property. Your verified account email will be used for review updates.</Text>{!confirmed&&<><Text style={styles.body}>Your name</Text><TextInput accessibilityLabel="Your name" value={name} onChangeText={setName} editable={!locked} maxLength={120} autoComplete="name" style={styles.input}/><Text style={styles.body}>Phone (optional)</Text><TextInput accessibilityLabel="Phone (optional)" value={phone} onChangeText={setPhone} editable={!locked} maxLength={40} keyboardType="phone-pad" style={styles.input}/><Text style={styles.body}>Household size (1–20)</Text><TextInput accessibilityLabel="Household size" value={household} onChangeText={setHousehold} editable={!locked} maxLength={2} keyboardType="number-pad" style={styles.input}/><Text style={styles.body}>Preferred move-in date (YYYY-MM-DD)</Text><TextInput accessibilityLabel="Preferred move-in date" value={moveIn} onChangeText={setMoveIn} editable={!locked} maxLength={10} autoCapitalize="none" style={styles.input}/><Text style={styles.body}>Tell us about your application</Text><TextInput accessibilityLabel="Application message" value={message} onChangeText={setMessage} editable={!locked} maxLength={2000} multiline style={[styles.input,{minHeight:120,textAlignVertical:'top'}]}/><Pressable accessibilityRole="checkbox" accessibilityState={{checked:consent,disabled:locked}} disabled={locked} onPress={()=>setConsent(!consent)}><Text style={styles.body}>{consent?'☑':'☐'} I consent to Open House Realty reviewing this application and contacting me about it.</Text></Pressable><Pressable accessibilityRole="button" disabled={busy} accessibilityState={{disabled:busy}} onPress={()=>void send()} style={styles.button}><Text style={styles.buttonText}>{busy?'Confirming…':uncertain?'Retry same application':'Submit application'}</Text></Pressable></>}{!!notice&&<Text accessibilityRole={confirmed?'text':'alert'} style={styles.body}>{notice}</Text>}{(uncertain||confirmed)&&<Link href="/applications" style={styles.link}>Check your stored applications →</Link>}{uncertain&&<Text style={styles.body}>Your details are held for the same retry while this screen is open. If you leave, check your account applications before sending again.</Text>}</View>;
}
