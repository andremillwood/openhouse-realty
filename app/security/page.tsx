import {redirect} from 'next/navigation';
import {createClient} from '@/lib/supabase/server';
import {SiteHeader} from '@/components/discovery/site-header';
export const dynamic = 'force-dynamic';
export default async function Security({searchParams}: {searchParams: Promise<Record<string, string | string[] | undefined>>}) {
  const client = await createClient(), {data: {user}, error} = await client.auth.getUser();
  if (error || !user?.email_confirmed_at) redirect('/sign-in');
  const input = await searchParams, reference = typeof input.permit === 'string' ? input.permit.trim() : '';
  const valid = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(reference);
  if (valid) redirect(`/security/entry/${reference}`);
  return <><SiteHeader/><main className="account-layout"><section className="account-card"><p className="eyebrow">Property security</p><h1>Check an entry permit</h1><p>Use the permit reference supplied by the contractor or property manager. Your account must have current security coverage for this property.</p><form className="staff-editor" action="/security"><label>Permit reference<input name="permit" required maxLength={36} placeholder="Paste the permit reference"/></label><button className="primary">Check permit</button>{reference && <p role="alert">Enter the full permit reference.</p>}</form></section></main></>;
}
