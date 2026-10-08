import {useEffect,useRef,useState} from 'react';
import {View,Text,TextInput,Pressable} from 'react-native';
import {Link,router,useLocalSearchParams} from 'expo-router';
import {invitationReturnId} from '../lib/invitation-link';
import {supabase} from '../lib/supabase';
import {useIdentity} from '../components/identity';
import {RecoveryRequest} from '../components/recovery-request';
import {ConfirmationResend} from '../components/confirmation-resend';
import {verifiedPasswordSignIn} from '../lib/account-access';
import {AuthShell,authStyles as a} from '../components/auth-shell';
export default function SignIn(){const params=useLocalSearchParams<{invitation?:string|string[]}>();const [email,setEmail]=useState(''),[password,setPassword]=useState(''),[busy,setBusy]=useState(false),[message,setMessage]=useState('');const [showPassword,setShowPassword]=useState(false),[help,setHelp]=useState<'recovery'|'confirmation'|null>(null);const active=useRef(false),mounted=useRef(true),complete=useRef(false);const {refresh}=useIdentity();
 useEffect(()=>{mounted.current=true;return()=>{mounted.current=false;};},[]);
 async function submit(){if(active.current||complete.current||!mounted.current)return;if(!supabase){setMessage('Account connection is not configured for this app.');return;}const invitation=invitationReturnId(params.invitation);active.current=true;setBusy(true);setMessage('');try{const expected=await verifiedPasswordSignIn(supabase,email,password);if(!mounted.current)return;setPassword('');await refresh();if(!mounted.current)return;const current=await supabase.auth.getUser();if(current.error||current.data.user?.id!==expected||!current.data.user.email_confirmed_at||current.data.user.is_anonymous)throw Error('Your signed-in account could not be verified. Try again.');if(!mounted.current)return;complete.current=true;if(invitation)router.replace({pathname:'/team-invitation',params:{id:invitation}});else router.replace('/');}catch(error){if(mounted.current)setMessage(error instanceof Error&&['Enter a valid email and password.','Unable to sign in. Check your details and try again.','Verify your email before signing in.','Your signed-in account could not be verified. Try again.','Account access could not be confirmed. Try signing out and signing in again.'].includes(error.message)?error.message:'Unable to sign in or save your session. Try again.');}finally{active.current=false;if(mounted.current)setBusy(false);}}
 return <AuthShell title="Welcome home." subtitle="Your properties, people and next chapter — all in one place.">
 <View style={a.field}><Text style={a.label}>Email address</Text><TextInput accessibilityLabel="Email" placeholder="you@example.com" placeholderTextColor="#94A3B8" autoCapitalize="none" autoCorrect={false} keyboardType="email-address" textContentType="emailAddress" value={email} onChangeText={setEmail} editable={!busy} style={a.input}/></View>
 <View style={a.field}><Text style={a.label}>Password</Text><View style={a.passwordRow}><TextInput accessibilityLabel="Password" placeholder="Enter your password" placeholderTextColor="#94A3B8" secureTextEntry={!showPassword} textContentType="password" value={password} onChangeText={setPassword} editable={!busy} style={a.password}/><Pressable accessibilityRole="button" accessibilityLabel={showPassword?'Hide password':'Show password'} onPress={()=>setShowPassword(!showPassword)} style={a.toggle}><Text style={a.smallLink}>{showPassword?'Hide':'Show'}</Text></Pressable></View></View>
 <Pressable accessibilityRole="button" accessibilityState={{expanded:help==='recovery'}} onPress={()=>setHelp(help==='recovery'?null:'recovery')}><Text style={a.smallLink}>Forgot your password?</Text></Pressable>
 <Pressable accessibilityRole="button" accessibilityState={{disabled:busy}} disabled={busy} onPress={()=>void submit()} style={[a.button,busy&&a.disabled]}><Text style={a.buttonText}>{busy?'Signing in…':'Sign in'}</Text></Pressable>
 {!!message&&<Text accessibilityRole="alert" style={a.message}>{message}</Text>}
 {help==='recovery'&&<RecoveryRequest/>}{help==='confirmation'&&<ConfirmationResend/>}
 <View style={a.divider}/><Link href="/register" style={a.switch}>New to Open House? Create an account →</Link>
 <Pressable accessibilityRole="button" accessibilityState={{expanded:help==='confirmation'}} onPress={()=>setHelp(help==='confirmation'?null:'confirmation')}><Text style={[a.smallLink,{textAlign:'center'}]}>Need a new confirmation email?</Text></Pressable>
 </AuthShell>;
}
