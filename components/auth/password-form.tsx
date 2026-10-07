'use client';
import { useState, type FormEvent } from 'react';
import { createClient } from '@/lib/supabase/client';
export function PasswordForm() {
  const [busy, setBusy] = useState(false);
  const [message, setMessage] = useState('');
  async function submit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault(); setBusy(true);
    const form = event.currentTarget;
    const password = String(new FormData(form).get('password') || '');
    try {
      const { error } = await createClient().auth.updateUser({ password });
      setMessage(error ? 'Unable to change your password. Sign in again and retry.' : 'Your password has been updated.');
      if (!error) form.reset();
    } catch { setMessage('Unable to change your password. Please retry.'); }
    finally { setBusy(false); }
  }
  return <form onSubmit={submit}><label>New password<input name="password" type="password" autoComplete="new-password" minLength={12} maxLength={128} required /></label><button disabled={busy}>{busy ? 'Updating…' : 'Update password'}</button><p role="status">{message}</p></form>;
}
