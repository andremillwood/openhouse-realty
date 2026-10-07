import {useCallback,useEffect,useRef,useState} from 'react';
import {ActivityIndicator,Pressable,Text,View} from 'react-native';
import {Link} from 'expo-router';
import {useIdentity} from './identity';
import {useLoad} from './use-load';
import {supabase} from '../lib/supabase';
import {savedStatus,setSaved} from '../lib/saves';
import {styles} from './styles';
export function SaveProperty({listingId,removeOnly=false,onChanged}:{listingId:string;removeOnly?:boolean;onChanged?:()=>void}){
 const {user,loading}=useIdentity();if(loading)return <ActivityIndicator accessibilityLabel="Checking your account"/>;
 if(!user)return <Link href="/sign-in" style={styles.link}>Sign in to save properties →</Link>;
 return <SaveControl key={user.id+listingId} owner={user.id} listingId={listingId} removeOnly={removeOnly} onChanged={onChanged}/>;
}
export function SaveControl({owner,listingId,removeOnly,onChanged}:{owner:string;listingId:string;removeOnly:boolean;onChanged?:()=>void}){
 const loader=useCallback(()=>{if(!supabase)throw new Error('Connection unavailable');return savedStatus(supabase,owner,listingId);},[owner,listingId]);
 const result=useLoad(owner+listingId,loader);const [confirmed,setConfirmed]=useState<boolean|null>(null),[busy,setBusy]=useState(false),[uncertain,setUncertain]=useState(false),[message,setMessage]=useState('');
 const active=useRef(false),attempt=useRef<boolean|null>(null),mounted=useRef(true);
 useEffect(()=>{mounted.current=true;return()=>{mounted.current=false;};},[]);
 const saved=confirmed??result.data;
 async function change(desired:boolean){if(active.current||!mounted.current||!supabase)return;active.current=true;attempt.current=desired;setBusy(true);setMessage('');
  try{const value=await setSaved(supabase,owner,listingId,desired);if(!mounted.current)return;setConfirmed(value);setUncertain(false);attempt.current=null;setMessage(value?'Saved to your account.':'Removed from your saved properties.');onChanged?.();}
  catch{if(mounted.current){setUncertain(true);setMessage('We could not confirm the change. Retry the same change or check the current status.');}}
  finally{active.current=false;if(mounted.current)setBusy(false);}
 }
 async function check(){if(active.current||!mounted.current||!supabase)return;active.current=true;setBusy(true);try{const value=await savedStatus(supabase,owner,listingId);if(mounted.current){setConfirmed(value);setUncertain(false);attempt.current=null;setMessage(value?'Currently saved to your account.':'Currently not saved.');onChanged?.();}}catch{if(mounted.current)setMessage('Unable to check the current status. Retry when your connection returns.');}finally{active.current=false;if(mounted.current)setBusy(false);}}
 if(result.loading&&confirmed===null)return <ActivityIndicator accessibilityLabel="Checking saved status"/>;
 if(result.error&&confirmed===null)return <View><Text accessibilityRole="alert" style={styles.body}>Unable to check whether this property is saved.</Text><Pressable accessibilityRole="button" onPress={result.retry}><Text style={styles.link}>Check saved status</Text></Pressable></View>;
 return <View style={{gap:12}}>{uncertain?<><Pressable accessibilityRole="button" disabled={busy} accessibilityState={{disabled:busy}} onPress={()=>{if(attempt.current!==null)void change(attempt.current);}} style={styles.button}><Text style={styles.buttonText}>{busy?'Checking…':'Retry same change'}</Text></Pressable><Pressable accessibilityRole="button" disabled={busy} onPress={()=>void check()}><Text style={styles.link}>Check current status</Text></Pressable></>:removeOnly&&!saved?<Text style={styles.body}>Removed from your saved properties.</Text>:<Pressable accessibilityRole="button" disabled={busy||saved===null} accessibilityState={{disabled:busy||saved===null,selected:!!saved}} onPress={()=>void change(!saved)} style={styles.button}><Text style={styles.buttonText}>{busy?'Updating…':saved?'♥ Remove from saved':'♡ Save property'}</Text></Pressable>}{!!message&&<Text accessibilityRole={uncertain?'alert':'text'} style={styles.body}>{message}</Text>}</View>;
}
