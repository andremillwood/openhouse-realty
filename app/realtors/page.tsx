import { SiteHeader } from '@/components/discovery/site-header';
import { LiveRealtors } from '@/components/discovery/live-realtors';
import { createClient } from '@/lib/supabase/server';
export const dynamic = 'force-dynamic';
export const metadata = { title:'Find your realtor | Open House Realty' };
export default async function Realtors() {
  const client = await createClient();
  const [{data:roster,error},{data:{user}}] = await Promise.all([
    client.from('realtor_profiles').select('id,display_name,bio,photo_url,service_areas,supported_intents,communication_style,guidance_style,decision_pace').eq('is_published',true).order('display_name').limit(200),client.auth.getUser(),
  ]);
  const {data:preferences} = user?.email_confirmed_at?await client.from('realtor_match_preferences').select('intent,preferred_area,communication_style,guidance_style,decision_pace,revision').eq('user_id',user.id).maybeSingle():{data:null};
  return <><SiteHeader/><main><section className="page-intro"><p className="eyebrow">EXPLORE THE EXPERIENCE</p><p><a className="button-link" href="/demo/realtors">Meet fictional demo realtors and try working-style matching ↗</a></p></section>{error?<section className="page-intro"><h1>The team is unavailable right now.</h1><p>Please try again shortly. We couldn’t load the realtor directory.</p></section>:null}<LiveRealtors roster={error?[]:roster||[]} initialPreferences={preferences}/></main></>;
}
