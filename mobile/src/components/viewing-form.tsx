import {useCallback,useEffect,useRef,useState} from 'react';
import {ActivityIndicator,Pressable,Text,TextInput,View} from 'react-native';
import {Link} from 'expo-router';
import {randomUUID} from 'expo-crypto';
import {useIdentity} from './identity';
import {styles} from './styles';
import {supabase} from '../lib/supabase';
import {EnquiryFailure} from '../lib/enquiries';
import {availableViewingSlots,viewingAttempt,requestViewing,type ViewingAttempt} from '../lib/viewings';
import {useLoad} from './use-load';
export function ViewingForm({listingId}:{listingId:string}){
 const {user,loading,error,refresh}=useIdentity();
 if(loading)return <ActivityIndicator accessibilityLabel="Checking your account"/>;
 if(error)return <View><Text accessibilityRole="alert" style={styles.body}>{error}</Text><Pressable accessibilityRole="button" onPress={()=>void refresh()}><Text style={styles.link}>Check account again</Text></Pressable></View>;
 if(!user)return <Link href="/sign-in" style={styles.link}>Sign in to request a viewing →</Link>;
 return <ViewingControl key={user.id+listingId} owner={user.id} listingId={listingId}/>;
}
export function ViewingControl({owner,listingId}:{owner:string;listingId:string}){
 const [name,setName]=useState(''),[phone,setPhone]=useState(''),[slotId,setSlotId]=useState(''),[consent,setConsent]=useState(false);
 const [busy,setBusy]=useState(false),[uncertain,setUncertain]=useState(false),[notice,setNotice]=useState(''),[confirmed,setConfirmed]=useState(false);
 const loader=useCallback(()=>{if(!supabase)throw new Error('Connection unavailable');return availableViewingSlots(supabase,listingId);},[listingId]);
 const availability=useLoad(listingId,loader);
 const active=useRef(false),attempt=useRef<ViewingAttempt|null>(null),mounted=useRef(true),complete=useRef(false);
 useEffect(()=>{mounted.current=true;return()=>{mounted.current=false;};},[]);
 async function send(){
  if(active.current||complete.current||!mounted.current)return;
  active.current=true;setBusy(true);setNotice('');
  const retrying=attempt.current!==null;
  try{
   if(!supabase)throw new EnquiryFailure('Account connection is unavailable.',false);
   const payload=attempt.current??viewingAttempt({requestId:randomUUID(),slotId,name,phone,consent});
   attempt.current=payload;
   const stored=await requestViewing(supabase,owner,payload);
   if(!mounted.current)return;
   complete.current=true;setConfirmed(true);setUncertain(false);setNotice(stored.status==='confirmed'?'Your viewing is confirmed. The team will arrange meeting details.':stored.status==='requested'?'Your viewing request is stored. It awaits team confirmation.':`Your stored request is now ${stored.status.replace('_',' ')}. Check your appointments before choosing another time.`);
  }catch(error){if(mounted.current){const unknown=retrying||!(error instanceof EnquiryFailure)||error.uncertain;setUncertain(unknown);if(!unknown)attempt.current=null;setNotice(error instanceof EnquiryFailure?error.message:'We could not confirm your viewing request. Retry the same request.');}}
  finally{active.current=false;if(mounted.current)setBusy(false);}
 }
 const locked=busy||uncertain||confirmed;
 return <View style={styles.card}><Text style={styles.heading}>Come see the possibilities.</Text><Text style={styles.body}>Choose a viewing time below. All times are in Jamaica. A request needs team confirmation.</Text>{!confirmed&&<>{availability.loading?<ActivityIndicator accessibilityLabel="Loading viewing times"/>:availability.error?<Text accessibilityRole="alert" style={styles.body}>Unable to load viewing times. Refresh availability.</Text>:availability.data?.length?<><Text style={styles.body}>Choose an available time</Text>{availability.data.map(slot=><Pressable key={slot.id} accessibilityRole="radio" accessibilityState={{checked:slotId===slot.id,disabled:locked}} disabled={locked} onPress={()=>setSlotId(slot.id)}><Text style={styles.link}>{slotId===slot.id?"◉":"○"} {new Date(slot.starts_at).toLocaleString("en-JM",{timeZone:"America/Jamaica"})} · {Math.round((Date.parse(slot.ends_at)-Date.parse(slot.starts_at))/60000)} minutes</Text></Pressable>)}</>:<Text style={styles.body}>No viewing times are currently available. Enquire with the team to arrange a visit.</Text>}<Pressable accessibilityRole="button" disabled={locked} onPress={()=>{setSlotId('');availability.retry();}}><Text style={styles.link}>Refresh availability</Text></Pressable><Text style={styles.body}>Your name</Text><TextInput accessibilityLabel="Your name" value={name} onChangeText={setName} editable={!locked} maxLength={120} autoComplete="name" style={styles.input}/><Text style={styles.body}>Phone (optional)</Text><TextInput accessibilityLabel="Phone (optional)" value={phone} onChangeText={setPhone} editable={!locked} maxLength={40} keyboardType="phone-pad" style={styles.input}/><Pressable accessibilityRole="checkbox" accessibilityState={{checked:consent,disabled:locked}} disabled={locked} onPress={()=>setConsent(!consent)}><Text style={styles.body}>{consent?'☑':'☐'} I agree that Open House Realty may contact me about this viewing request.</Text></Pressable><Pressable accessibilityRole="button" disabled={busy||(!uncertain&&(!slotId||availability.loading||!!availability.error))} accessibilityState={{disabled:busy||(!uncertain&&(!slotId||availability.loading||!!availability.error))}} onPress={()=>void send()} style={styles.button}><Text style={styles.buttonText}>{busy?'Confirming…':uncertain?'Retry same viewing request':'Request viewing'}</Text></Pressable></>}{!!notice&&<Text accessibilityRole={confirmed?'text':'alert'} style={styles.body}>{notice}</Text>}{(uncertain||confirmed)&&<Link href="/appointments" style={styles.link}>Check your appointments →</Link>}{uncertain&&<Text style={styles.body}>Your details are held for the same retry while this screen is open. If you leave, check your account appointments before sending again.</Text>}</View>;
}
