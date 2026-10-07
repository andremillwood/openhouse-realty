import type {SupabaseClient} from '@supabase/supabase-js';
export const nativeConfirmationUrl='openhouse-realty://auth/confirm';
export const nativeRecoveryUrl='openhouse-realty://auth/recover';
export async function requestNativeRecovery(client:SupabaseClient,email:string){
 const normalized=email.trim();if(normalized.length>254||!/^\S+@\S+\.\S+$/.test(normalized))throw new Error('Enter a valid email.');
 const current=await client.auth.getSession();if(current.error||current.data.session)throw new Error('Sign out before requesting password recovery.');
 const result=await client.auth.resetPasswordForEmail(normalized,{redirectTo:nativeRecoveryUrl});
 if(result.error)throw new Error('Recovery request could not be confirmed. Check your email before retrying.');
 return 'check_email' as const;
}
export async function confirmNativeRecovery(client:SupabaseClient,code:string){
 if(typeof code!=='string'||!code||code.length>2048||/\s|[\x00-\x1f\x7f]/.test(code))throw new Error('Invalid recovery link.');
 const result=await client.auth.exchangeCodeForSession(code);
 if(result.error||!('redirectType' in result.data)||result.data.redirectType!=='recovery'||!result.data.session||!result.data.user?.email_confirmed_at||result.data.user.is_anonymous)throw new Error('Recovery session could not be verified.');
 const fresh=await client.auth.getUser();
 if(fresh.error||fresh.data.user?.id!==result.data.user.id||!fresh.data.user.email_confirmed_at||fresh.data.user.is_anonymous)throw new Error('Recovery session could not be verified.');
 return fresh.data.user.id;
}
export async function updateRecoveredPassword(client:SupabaseClient,owner:string,password:string){
 if(password.length<12||password.length>1024)throw new Error('Use a password of at least 12 characters.');
 const current=await client.auth.getUser();if(current.error||current.data.user?.id!==owner||!current.data.user.email_confirmed_at||current.data.user.is_anonymous)throw new Error('Recovery account changed.');
 const result=await client.auth.updateUser({password});if(result.error||result.data.user?.id!==owner)throw new Error('Password update could not be confirmed.');
 return owner;
}
export async function resendNativeConfirmation(client:SupabaseClient,email:string){
 const normalized=email.trim();if(normalized.length>254||!/^\S+@\S+\.\S+$/.test(normalized))throw new Error('Enter a valid email.');
 const current=await client.auth.getSession();if(current.error||current.data.session)throw new Error('Sign out before requesting confirmation.');
 const result=await client.auth.resend({type:'signup',email:normalized,options:{emailRedirectTo:nativeConfirmationUrl}});
 if(result.error)throw new Error('Confirmation request could not be confirmed. Check your email and wait before retrying.');
 return 'check_email' as const;
}
export async function registerNativeAccount(client:SupabaseClient,email:string,password:string,consent:boolean){
 const normalized=email.trim();
 if(!consent||normalized.length>254||!/^\S+@\S+\.\S+$/.test(normalized)||password.length<12||password.length>1024)throw new Error('Confirm account creation with a valid email and a password of at least 12 characters.');
 const current=await client.auth.getSession();if(current.error||current.data.session)throw new Error('Sign out before creating another account.');
 const result=await client.auth.signUp({email:normalized,password,options:{emailRedirectTo:nativeConfirmationUrl}});
 if(result.error)throw new Error('Registration could not be confirmed. Check your email before trying again.');
 // Confirmation-disabled installations must not silently grant app access here.
 if(result.data.session){const removed=await client.auth.signOut({scope:'local'});if(removed.error)throw new Error('Registration session could not be closed. Sign out before continuing.');}
 return 'check_email' as const;
}
export async function confirmNativeAccount(client:SupabaseClient,code:string){
 if(typeof code!=='string'||!code||code.length>2048||/\s|[\x00-\x1f\x7f]/.test(code))throw new Error('Invalid confirmation link.');
 const exchanged=await client.auth.exchangeCodeForSession(code);
 if(exchanged.error||!exchanged.data.session||!exchanged.data.user?.email_confirmed_at||exchanged.data.user.is_anonymous)throw new Error('Confirmation could not be verified. Return to sign-in or request a new confirmation.');
 const fresh=await client.auth.getUser();
 if(fresh.error||fresh.data.user?.id!==exchanged.data.user.id||!fresh.data.user.email_confirmed_at||fresh.data.user.is_anonymous)throw new Error('Confirmation could not be verified. Return to sign-in or request a new confirmation.');
 return fresh.data.user.id;
}
export async function verifiedPasswordSignIn(client:SupabaseClient,email:string,password:string){
 const normalized=email.trim();
 if(normalized.length>254||!/^\S+@\S+\.\S+$/.test(normalized)||!password||password.length>1024)throw new Error('Enter a valid email and password.');
 const result=await client.auth.signInWithPassword({email:normalized,password});
 if(result.error||!result.data.user||!result.data.session)throw new Error('Unable to sign in. Check your details and try again.');
 const expected=result.data.user.id;
 if(!result.data.user.email_confirmed_at||result.data.user.is_anonymous){
  const removed=await client.auth.signOut({scope:'local'});
  if(removed.error)throw new Error('Account access could not be confirmed. Try signing out and signing in again.');
  throw new Error('Verify your email before signing in.');
 }
 const fresh=await client.auth.getUser();
 if(fresh.error||fresh.data.user?.id!==expected||!fresh.data.user.email_confirmed_at||fresh.data.user.is_anonymous)throw new Error('Your signed-in account could not be verified. Try again.');
 return expected;
}
