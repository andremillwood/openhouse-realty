import {NextRequest,NextResponse} from 'next/server';
import {sameOrigin} from '@/lib/http/origin';
import {boundedText} from '@/lib/http/body';
import {createClient} from '@/lib/supabase/server';
import {cosignerInput} from '@/lib/applications/cosigner';
export async function POST(request:NextRequest){
 if(!sameOrigin(request))return NextResponse.json({error:'Invalid request origin.'},{status:403});
 if(!request.headers.get('content-type')?.includes('application/json'))return NextResponse.json({error:'JSON required.'},{status:415});
 const client=await createClient();const {data:{user},error:authError}=await client.auth.getUser();if(authError||!user?.email_confirmed_at)return NextResponse.json({error:'Sign in with a verified account.'},{status:401});
 let body;try{body=await boundedText(request,4000);}catch{return NextResponse.json({error:'Request too large.'},{status:413});}
 let input;try{input=cosignerInput(JSON.parse(body));}catch(error){return NextResponse.json({error:error instanceof Error?error.message:'Invalid co-signer request.'},{status:400});}
 const {data,error}=await client.rpc(input.name,input.args);
 if(error){const status=error.code==='42501'?403:['40001','23505'].includes(error.code)?409:error.code==='P0001'?429:400;return NextResponse.json({error:status===403?'Invitation access requires the applicant or the invited verified account.':status===409?'Invitation changed or already exists. Refresh before retrying.':status===429?'Invitation limit reached. Review existing invitations.':'Unable to record this invitation action. Check consent, expiry and application stage.'},{status});}
 return NextResponse.json(input.name==='invite_application_cosigner'?{id:data}:data,{headers:{'Cache-Control':'no-store'}});
}
