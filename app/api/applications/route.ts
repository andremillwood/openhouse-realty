import {NextRequest,NextResponse} from 'next/server';
import {sameOrigin} from '@/lib/http/origin';
import {boundedText} from '@/lib/http/body';
import {createClient} from '@/lib/supabase/server';
import {applicationInput,applicationTransition} from '@/lib/applications/validation';
async function handle(request:NextRequest,update:boolean){
 if(!sameOrigin(request))return NextResponse.json({error:'Invalid request origin.'},{status:403});
 if(!request.headers.get('content-type')?.includes('application/json'))return NextResponse.json({error:'JSON required.'},{status:415});
 const client=await createClient();const {data:{user},error:authError}=await client.auth.getUser();
 if(authError||!user?.email_confirmed_at)return NextResponse.json({error:'Sign in with a verified email first.'},{status:401});
 let body;try{body=await boundedText(request,12000);}catch{return NextResponse.json({error:'Request too large or unreadable.'},{status:413});}
 let input;try{input=update?applicationTransition(JSON.parse(body)):applicationInput(JSON.parse(body));}catch(error){return NextResponse.json({error:error instanceof Error?error.message:'Invalid application.'},{status:400});}
 const {data,error}=await client.rpc(update?'transition_rental_application':'submit_rental_application',input);
 if(error){const status=error.code==='42501'?403:error.code==='40001'||error.code==='23505'?409:error.code==='P0001'?429:400;return NextResponse.json({error:status===409?'The application changed or an active application already exists. Refresh your account before retrying.':status===429?'Application limit reached. Review your existing applications before trying again.':status===403?'Application access is unavailable. Check your account and staff permissions.':'Unable to store this request. Check the property, dates and review stage.'},{status});}
 return NextResponse.json(update?data:{id:data},{status:update?200:201,headers:{'Cache-Control':'no-store'}});
}
export const POST=(request:NextRequest)=>handle(request,false);
export const PATCH=(request:NextRequest)=>handle(request,true);
