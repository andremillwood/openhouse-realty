import {NextRequest,NextResponse} from 'next/server';
import {createClient} from '@/lib/supabase/server';
import {sameOrigin} from '@/lib/http/origin';
import {boundedText} from '@/lib/http/body';
const headers={'Cache-Control':'private, no-store'};
const json=(body:unknown,status=200)=>NextResponse.json(body,{status,headers});
export async function POST(request:NextRequest){
 if(!sameOrigin(request))return json({error:'Invalid request origin.'},403);
 if(!request.headers.get('content-type')?.includes('application/json'))return json({error:'JSON required.'},415);
 let client:Awaited<ReturnType<typeof createClient>>;
 try{client=await createClient();const {data:{user},error:authError}=await client.auth.getUser();if(authError||!user?.email_confirmed_at)return json({error:'Verified sign-in required to save or delete preferences.'},401);}catch{return json({error:'Account access could not be confirmed. Please try again.'},503);}
 let body;try{body=await boundedText(request,2500);}catch{return json({error:'Request too large.'},413);}
 let input;try{input=JSON.parse(body);if(!input||typeof input!=='object'||Array.isArray(input)||!['save','delete'].includes(input.action)||!(input.revision===null||typeof input.revision==='string'&&/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(input.revision)))throw Error();}catch{return json({error:'Check your preference request.'},400);}
 try{
  const {data,error}=await client.rpc('manage_matching_preferences',{p_action:input.action,p_expected_revision:input.revision,p_preferences:input.action==='save'?input.preferences:null,p_consent:input.action==='save'&&input.consent===true});
  if(error){const status=error.code==='40001'?409:error.code==='42501'?403:['22023','22P02'].includes(error.code)?400:503;return json({error:status===409?'Preferences changed in another visit. Refresh this page before retrying.':status===503?'The update could not be confirmed. Refresh this page to check stored preferences before trying again.':'Unable to update preferences. Check your answers and consent.'},status);}
  const uuid=/^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
  if(!data||(input.action==='delete'?(data.status!=='deleted'||data.revision!==null):(data.status!=='saved'||typeof data.revision!=='string'||!uuid.test(data.revision))))return json({error:'The update could not be confirmed. Refresh this page to check stored preferences before trying again.'},503);
  return json({status:data.status,revision:data.revision});
 }catch{return json({error:'The update could not be confirmed. Refresh this page to check stored preferences before trying again.'},503);}
}
