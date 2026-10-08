'use client';
import {propertySignInHref} from '@/lib/auth-return';
import {useRouter} from 'next/navigation';
import { useRef, useState } from 'react';
import { createClient } from '@/lib/supabase/client';
export function SaveProperty({ listingId, initialSaved = false, refreshAfterChange = false }: { listingId: string; initialSaved?: boolean; refreshAfterChange?: boolean }) {
  const router=useRouter();
  const active=useRef(false);
  const [saved, setSaved] = useState(initialSaved);
  const [busy, setBusy] = useState(false);
  const [message, setMessage] = useState('');
  async function toggle() {
    if(active.current)return;
    active.current=true;
    setBusy(true); setMessage('');
    try {
      const client = createClient();
      const { data: { user }, error: authError } = await client.auth.getUser();
      if (authError || !user?.email_confirmed_at || user.is_anonymous) { window.location.assign(propertySignInHref(listingId)); return; }
      const { error } = saved
        ? await client.from('saved_listings').delete().eq('user_id', user.id).eq('listing_id', listingId)
        : await client.from('saved_listings').upsert({ user_id: user.id, listing_id: listingId }, { onConflict: 'user_id,listing_id', ignoreDuplicates: true });
      if (error) throw error;
      setSaved(!saved);
      setMessage(saved ? 'Removed from your saved properties.' : 'Saved to your account.');
      if(refreshAfterChange)router.refresh();
    } catch { setMessage('Unable to update saved properties. Please retry.'); }
    finally { active.current=false;setBusy(false); }
  }
  return <div><button className="primary" disabled={busy} aria-pressed={saved} onClick={toggle}>{busy ? 'Updating…' : saved ? '♥ Saved' : '♡ Save property'}</button><p role="status">{message}</p></div>;
}
