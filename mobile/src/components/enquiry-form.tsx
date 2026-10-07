import {useEffect,useRef,useState} from 'react';
import {ActivityIndicator,Pressable,Text,TextInput,View} from 'react-native';
import {Link} from 'expo-router';
import {randomUUID} from 'expo-crypto';
import {useIdentity} from './identity';
import {styles} from './styles';
import {supabase} from '../lib/supabase';
import {enquiryAttempt,EnquiryFailure,submitEnquiry,type EnquiryAttempt} from '../lib/enquiries';
export function EnquiryForm({listingId,realtorId}:{listingId?:string;realtorId?:string}){
 const {user,loading,error,refresh}=useIdentity();
 if(loading)return <ActivityIndicator accessibilityLabel="Checking your account"/>;
 if(error)return <View><Text accessibilityRole="alert" style={styles.body}>{error}</Text><Pressable accessibilityRole="button" onPress={()=>void refresh()}><Text style={styles.link}>Check account again</Text></Pressable></View>;
 if(!user)return <Link href="/sign-in" style={styles.link}>Sign in to enquire →</Link>;
 return <EnquiryControl key={user.id+':'+(listingId||realtorId)} owner={user.id} listingId={listingId} realtorId={realtorId}/>;
}
export function EnquiryControl({owner,listingId,realtorId}:{owner:string;listingId?:string;realtorId?:string}){
 const [name,setName]=useState(''),[phone,setPhone]=useState(''),[message,setMessage]=useState(''),[consent,setConsent]=useState(false);
 const [busy,setBusy]=useState(false),[uncertain,setUncertain]=useState(false),[notice,setNotice]=useState(''),[confirmed,setConfirmed]=useState(false);
 const active=useRef(false),attempt=useRef<EnquiryAttempt|null>(null),mounted=useRef(true),complete=useRef(false);
 useEffect(()=>{mounted.current=true;return()=>{mounted.current=false;};},[]);
 async function send(){
  if(active.current||complete.current||!mounted.current)return;
  active.current=true;setBusy(true);setNotice('');
  const retrying=attempt.current!==null;
  try{
   if(!supabase)throw new EnquiryFailure('Account connection is unavailable.',false);
   const payload=attempt.current??enquiryAttempt({requestId:randomUUID(),listingId,realtorId,name,phone,message,consent});
   attempt.current=payload;
   await submitEnquiry(supabase,owner,payload);
   if(!mounted.current)return;
   complete.current=true;setConfirmed(true);setUncertain(false);setNotice('Your enquiry is stored. The team will follow up. A viewing still requires confirmation.');
  }catch(error){if(mounted.current){const unknown=retrying||!(error instanceof EnquiryFailure)||error.uncertain;setUncertain(unknown);if(!unknown)attempt.current=null;setNotice(error instanceof EnquiryFailure?error.message:'We could not confirm your enquiry. Retry the same request.');}}
  finally{active.current=false;if(mounted.current)setBusy(false);}
 }
 const locked=busy||uncertain||confirmed;
 return <View style={styles.card}><Text style={styles.heading}>Make your next move.</Text><Text style={styles.body}>{realtorId?'Request an introduction to this realtor.':'Ask the team about this property.'} Your verified account email will be used to reply.</Text>{!confirmed&&<><Text style={styles.body}>Your name</Text><TextInput accessibilityLabel="Your name" value={name} onChangeText={setName} editable={!locked} maxLength={120} autoComplete="name" style={styles.input}/><Text style={styles.body}>Phone (optional)</Text><TextInput accessibilityLabel="Phone (optional)" value={phone} onChangeText={setPhone} editable={!locked} maxLength={40} keyboardType="phone-pad" style={styles.input}/><Text style={styles.body}>How can we help?</Text><TextInput accessibilityLabel="Enquiry message" value={message} onChangeText={setMessage} editable={!locked} maxLength={4000} multiline style={[styles.input,{minHeight:120,textAlignVertical:'top'}]}/><Pressable accessibilityRole="checkbox" accessibilityState={{checked:consent,disabled:locked}} disabled={locked} onPress={()=>setConsent(!consent)}><Text style={styles.body}>{consent?'☑':'☐'} I agree that Open House Realty may contact me about this enquiry.</Text></Pressable><Pressable accessibilityRole="button" disabled={busy} accessibilityState={{disabled:busy}} onPress={()=>void send()} style={styles.button}><Text style={styles.buttonText}>{busy?'Confirming…':uncertain?'Retry same enquiry':'Send enquiry'}</Text></Pressable></>}{!!notice&&<Text accessibilityRole={confirmed?'text':'alert'} style={styles.body}>{notice}</Text>}{(uncertain||confirmed)&&<Link href="/enquiries" style={styles.link}>Check your stored enquiries →</Link>}{uncertain&&<Text style={styles.body}>Your details are held for the same retry while this screen is open. If you leave, check your account enquiries before sending again.</Text>}</View>;
}
