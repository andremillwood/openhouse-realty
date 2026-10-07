import 'server-only';
import {createClient} from '@supabase/supabase-js';
export class NativeAuthFailure extends Error{constructor(public readonly status:401|503){super(status===401?'Verified native sign-in required.':'Account access could not be confirmed.');}}
export async function nativeServerIdentity(request:Request){
 const header=request.headers.get('authorization');
 if(!header||header.length>8192||!/^Bearer [A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+$/.test(header))throw new NativeAuthFailure(401);
 const token=header.slice(7),url=process.env.NEXT_PUBLIC_SUPABASE_URL,key=process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY;
 if(url!=='https://zikxzkbfxgdilykyyswt.supabase.co'||!key?.startsWith('sb_publishable_'))throw new NativeAuthFailure(503);
 const client=createClient(url,key,{global:{headers:{Authorization:header}},auth:{persistSession:false,autoRefreshToken:false,detectSessionInUrl:false}});
 try{const {data,error}=await client.auth.getUser(token);if(error){const status='status' in error?error.status:undefined;throw new NativeAuthFailure(status===400||status===401||status===403?401:503);}if(!data.user?.email_confirmed_at||data.user.is_anonymous)throw new NativeAuthFailure(401);return {client,user:data.user};}catch(error){if(error instanceof NativeAuthFailure)throw error;throw new NativeAuthFailure(503);}
}
