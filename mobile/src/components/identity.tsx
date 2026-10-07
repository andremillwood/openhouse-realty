import {createContext,useCallback,useContext,useEffect,useRef,useState,type ReactNode} from 'react';
import {AppState} from 'react-native';
import type {User} from '@supabase/supabase-js';
import {supabase} from '../lib/supabase';
type Identity={user:User|null;loading:boolean;error:string;refresh:()=>Promise<void>};
const Context=createContext<Identity>({user:null,loading:true,error:'',refresh:async()=>{}});
export function IdentityProvider({children}:{children:ReactNode}){
 const [user,setUser]=useState<User|null>(null),[loading,setLoading]=useState(true),[error,setError]=useState('');
 const epoch=useRef(0),mounted=useRef(true);
 const invalidate=useCallback(()=>{++epoch.current;},[]);
 const refresh=useCallback(async()=>{
  const request=++epoch.current;setUser(null);setLoading(true);setError('');
  if(!supabase){setError('Account connection is not configured for this app.');setLoading(false);return;}
  try{const {data,error}=await supabase.auth.getUser();if(!mounted.current||request!==epoch.current)return;
   if(error){if(error.name!=='AuthSessionMissingError')setError('Unable to verify your account. Try again.');setUser(null);}else setUser(data.user?.email_confirmed_at?data.user:null);
  }catch{if(mounted.current&&request===epoch.current){setUser(null);setError('Unable to verify your account. Try again.');}}
  finally{if(mounted.current&&request===epoch.current)setLoading(false);}
 },[]);
 useEffect(()=>{
  mounted.current=true;queueMicrotask(()=>{if(mounted.current)void refresh();});
  const listener=supabase?.auth.onAuthStateChange(()=>{queueMicrotask(()=>{if(mounted.current)void refresh();});});
  if(AppState.currentState==='active')supabase?.auth.startAutoRefresh();
  const state=AppState.addEventListener('change',value=>{if(value==='active'){supabase?.auth.startAutoRefresh();void refresh();}else{supabase?.auth.stopAutoRefresh();++epoch.current;setUser(null);setLoading(true);}});
  return()=>{mounted.current=false;invalidate();listener?.data.subscription.unsubscribe();state.remove();supabase?.auth.stopAutoRefresh();};
 },[refresh,invalidate]);
 return <Context.Provider value={{user,loading,error,refresh}}>{children}</Context.Provider>;
}
export const useIdentity=()=>useContext(Context);
