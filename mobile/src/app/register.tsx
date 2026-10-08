import {useEffect,useRef,useState} from 'react';
import {View,Text,TextInput,Pressable} from 'react-native';
import {Link} from 'expo-router';
import {supabase} from '../lib/supabase';
import {registerNativeAccount} from '../lib/account-access';
import {AuthShell,authStyles as a} from '../components/auth-shell';
export default function Register(){
 const [email,setEmail]=useState(''),[password,setPassword]=useState(''),[consent,setConsent]=useState(false),[busy,setBusy]=useState(false),[done,setDone]=useState(false),[message,setMessage]=useState('');const [showPassword,setShowPassword]=useState(false);const active=useRef(false),mounted=useRef(true),complete=useRef(false);
 useEffect(()=>{mounted.current=true;return()=>{mounted.current=false;};},[]);
 async function submit(){if(active.current||complete.current||!mounted.current||!supabase)return;active.current=true;setBusy(true);try{await registerNativeAccount(supabase,email,password,consent);if(!mounted.current)return;complete.current=true;setDone(true);setPassword('');setMessage('If registration is available for this email, check your inbox and spam folder. Open the newest confirmation on this device, then sign in. This does not confirm email delivery or account access.');}catch(error){if(mounted.current)setMessage(error instanceof Error&&error.message==='Sign out before creating another account.'?error.message:'Registration could not be confirmed. Use a valid email, a password of at least 12 characters and confirm account creation. Check your email before retrying.');}finally{active.current=false;if(mounted.current)setBusy(false);}}
 return <AuthShell title={done?'Check your inbox.':'Find your place.'} subtitle={done?'Confirm your email to take the next step.':'Save the homes you love and connect with the right people.'}>
 {!supabase&&<Text style={a.message}>Account connection is unavailable.</Text>}
 {!done&&<><View style={a.field}><Text style={a.label}>Email address</Text><TextInput accessibilityLabel="Email" placeholder="you@example.com" placeholderTextColor="#94A3B8" autoCapitalize="none" autoCorrect={false} keyboardType="email-address" textContentType="emailAddress" value={email} onChangeText={setEmail} editable={!busy} style={a.input}/></View>
 <View style={a.field}><Text style={a.label}>Create a password</Text><View style={a.passwordRow}><TextInput accessibilityLabel="New password, at least 12 characters" placeholder="At least 12 characters" placeholderTextColor="#94A3B8" secureTextEntry={!showPassword} textContentType="newPassword" value={password} onChangeText={setPassword} editable={!busy} style={a.password}/><Pressable accessibilityRole="button" accessibilityLabel={showPassword?'Hide password':'Show password'} onPress={()=>setShowPassword(!showPassword)} style={a.toggle}><Text style={a.smallLink}>{showPassword?'Hide':'Show'}</Text></Pressable></View></View>
 <Pressable accessibilityRole="checkbox" accessibilityState={{checked:consent,disabled:busy}} disabled={busy} onPress={()=>setConsent(!consent)} style={a.check}><Text style={[a.checkBox,consent&&a.checked]}>{consent?'✓':''}</Text><Text style={a.checkText}>I want to create an account using this email.</Text></Pressable>
 <Pressable accessibilityRole="button" accessibilityState={{disabled:busy||!consent||!supabase}} disabled={busy||!consent||!supabase} onPress={()=>void submit()} style={[a.button,(busy||!consent||!supabase)&&a.disabled]}><Text style={a.buttonText}>{busy?'Creating your account…':'Create account'}</Text></Pressable>
 <Text style={a.hint}>This creates a prospect account. The Open House team assigns staff and resident access separately.</Text></>}
 {!!message&&<Text accessibilityLiveRegion="polite" style={a.message}>{message}</Text>}
 <View style={a.divider}/><Link href="/sign-in" style={a.switch}>Already have an account? Sign in →</Link>
 </AuthShell>;
}
