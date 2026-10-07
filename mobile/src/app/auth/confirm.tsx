import {useEffect,useRef,useState} from 'react';
import {Link,useLocalSearchParams} from 'expo-router';
import {Text,View} from 'react-native';
import {supabase} from '../../lib/supabase';
import {confirmNativeAccount} from '../../lib/account-access';
import {useIdentity} from '../../components/identity';
import {styles} from '../../components/styles';
export default function Confirmation(){
 const params=useLocalSearchParams<{code?:string|string[];error?:string|string[]}>();const code=typeof params.code==='string'?params.code:'';return <ConfirmationAttempt key={code+String(!!params.error)} code={code} invalid={!!params.error}/>;
}
function ConfirmationAttempt({code,invalid}:{code:string;invalid:boolean}){const {refresh}=useIdentity();
 const [message,setMessage]=useState(!supabase||!code||invalid?'This confirmation link is unavailable. Return to sign-in or request a new link.':'Checking your confirmation…'),[done,setDone]=useState(false);const active=useRef(false),mounted=useRef(true),attempted=useRef('');
 useEffect(()=>{mounted.current=true;return()=>{mounted.current=false;};},[]);
 useEffect(()=>{if(active.current||attempted.current===code&&code)return;attempted.current=code;
  if(!supabase||!code||invalid)return;
  active.current=true;
  void (async()=>{try{const expected=await confirmNativeAccount(supabase,code);if(!mounted.current)return;await refresh();if(!mounted.current)return;const current=await supabase.auth.getUser();if(current.error||current.data.user?.id!==expected||!current.data.user.email_confirmed_at||current.data.user.is_anonymous)throw Error();if(!mounted.current)return;setDone(true);setMessage('Your email is verified. You can continue with your account.');}catch{if(mounted.current)setMessage('Confirmation could not be verified. Open the latest email on the device where registration began, or return to sign-in.');}finally{active.current=false;}})();
 },[code,invalid,refresh]);
 return <View style={styles.page}><Text style={styles.title}>Email confirmation.</Text><Text accessibilityLiveRegion="polite" style={styles.body}>{message}</Text><Link href={done?'/':'/sign-in'} style={styles.link}>{done?'Continue →':'Return to sign-in →'}</Link></View>;
}
