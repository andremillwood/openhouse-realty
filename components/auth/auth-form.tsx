'use client';
import { useState, type FormEvent } from 'react';
import { createClient } from '@/lib/supabase/client';

export function AuthForm({ confirmationError = false }: { confirmationError?: boolean }) {
  const [mode, setMode] = useState<'signin' | 'signup' | 'reset'>('signin');
  const [busy, setBusy] = useState(false);
  const [message, setMessage] = useState(confirmationError ? 'That confirmation link could not be completed. Request a new email or sign in.' : '');
  async function submit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setBusy(true); setMessage('');
    const data = new FormData(event.currentTarget);
    const email = String(data.get('email') || '').trim();
    const password = String(data.get('password') || '');
    const client = createClient();
    try {
      if (mode === 'reset') {
        const { error } = await client.auth.resetPasswordForEmail(email, { redirectTo: `${window.location.origin}/auth/confirm` });
        if (error) throw error;
        setMessage('If an account exists for this email, you will receive a recovery link. Open it to change your password in your account.');
      } else if (mode === 'signup') {
        const { error } = await client.auth.signUp({ email, password, options: { emailRedirectTo: `${window.location.origin}/auth/confirm` } });
        if (error) throw error;
        setMessage('Check your inbox to confirm your email, then sign in. New accounts have prospect access.');
      } else {
        const { data: result, error } = await client.auth.signInWithPassword({ email, password });
        if (error || !result.user?.email_confirmed_at) throw new Error('signin');
        window.location.assign('/account');
      }
    } catch {
      setMessage(mode === 'signin' ? 'Unable to sign in. Check your email and password, and confirm your email first.' : 'Unable to complete this request. Please try again shortly.');
    } finally { setBusy(false); }
  }
  return <section className="account-card">
    <p className="account-eyebrow">Your Open House account</p>
    <h1>{mode === 'signup' ? 'Make yourself at home.' : mode === 'reset' ? 'Recover your account.' : 'Welcome home.'}</h1>
    <p>Use your own verified account. The client demo is available separately.</p>
    <form onSubmit={submit}>
      <label>Email address<input name="email" type="email" autoComplete="email" required maxLength={254} /></label>
      {mode !== 'reset' && <label>Password<input name="password" type="password" autoComplete={mode === 'signup' ? 'new-password' : 'current-password'} minLength={mode === 'signup' ? 12 : 1} maxLength={128} required /></label>}
      {mode === 'signup' && <small>Use at least 12 characters. Staff access is assigned separately.</small>}
      <button disabled={busy} type="submit">{busy ? 'Please wait…' : mode === 'signup' ? 'Create account' : mode === 'reset' ? 'Send recovery link' : 'Sign in'}</button>
    </form>
    <p role="status" aria-live="polite">{message}</p>
    <div className="account-links"><button onClick={() => { setMode(mode === 'signup' ? 'signin' : 'signup'); setMessage(''); }} disabled={busy}>{mode === 'signup' ? 'Already have an account? Sign in' : 'Create an account'}</button><button onClick={() => { setMode(mode === 'reset' ? 'signin' : 'reset'); setMessage(''); }} disabled={busy}>{mode === 'reset' ? 'Back to sign in' : 'Forgot password?'}</button></div>
    <a href="/demo">Explore the client demo ↗</a>
  </section>;
}
