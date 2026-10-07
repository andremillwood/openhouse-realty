import 'server-only';
import { createClient } from '@supabase/supabase-js';
/** Only trusted server operations may use this client; authorize users through RLS first. */
export function createAdminClient(){
 const url=process.env.NEXT_PUBLIC_SUPABASE_URL;const key=process.env.SUPABASE_SECRET_KEY;
 if(!url||!key||key.includes('YOUR-')||key.length<30)throw new Error('Background database credential is not configured.');
 return createClient(url,key,{auth:{persistSession:false,autoRefreshToken:false,detectSessionInUrl:false}});
}
