'use client';
import {propertySignInHref} from '@/lib/auth-return';
import { useState } from 'react';
import { createClient } from '@/lib/supabase/client';
export function SaveProperty({ listingId, initialSaved = false }: { listingId: string; initialSaved?: boolean }) {
  const [saved, setSaved] = useState(initialSaved);
  const [busy, setBusy] = useState(false);
  const [message, setMessage] = useState('');
  async function toggle() {
    setBusy(true); setMessage('');
    try {
      const client = createClient();
      const { data: { user }, error: authError } = await client.auth.getUser();
      if (authError || !user?.email_confirmed_at) { window.location.assign(propertySignInHref(listingId)); return; }
      const { error } = saved
        ? await client.from('saved_listings').delete().eq('user_id', user.id).eq('listing_id', listingId)
        : await client.from('saved_listings').upsert({ user_id: user.id, listing_id: listingId }, { onConflict: 'user_id,listing_id', ignoreDuplicates: true });
      if (error) throw error;
      setSaved(!saved);
      setMessage(saved ? 'Removed from your saved properties.' : 'Saved to your account.');
    } catch { setMessage('Unable to update saved properties. Please retry.'); }
    finally { setBusy(false); }
  }
  return <div><button className="primary" disabled={busy} aria-pressed={saved} onClick={toggle}>{busy ? 'Updating…' : saved ? '♥ Saved' : '♡ Save property'}</button><p role="status">{message}</p></div>;
}
