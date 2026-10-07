import {NextRequest,NextResponse} from 'next/server';
import {sameOrigin} from '@/lib/http/origin';
import {boundedText} from '@/lib/http/body';
import {createClient} from '@/lib/supabase/server';
import {approvalInput} from '@/lib/applications/approval';
export async function POST(request:NextRequest){
 if(!sameOrigin(request))return NextResponse.json({error:'Invalid request origin.'},{status:403});
 if(!request.headers.get('content-type')?.includes('application/json'))return NextResponse.json({error:'JSON required.'},{status:415});
 const client=await createClient();const {data:{user},error:authError}=await client.auth.getUser();if(authError||!user?.email_confirmed_at)return NextResponse.json({error:'Verified staff sign-in required.'},{status:401});
 let body;try{body=await boundedText(request,12000);}catch{return NextResponse.json({error:'Request too large.'},{status:413});}
 let input;try{input=approvalInput(JSON.parse(body));}catch(error){return NextResponse.json({error:error instanceof Error?error.message:'Invalid approval request.'},{status:400});}
 const {data,error}=await client.rpc(input.name,input.args);
 if(error){const status=error.code==='42501'?403:['40001','23505'].includes(error.code)?409:400;return NextResponse.json({error:status===403?'An independent reviewer authorized by the business policy is required. Policy changes require an administrator.':status===409?'The application, policy or unit availability changed. Refresh before retrying.':'Approval checks are incomplete. Confirm the approved policy, verified documents, co-signer consent, current rental terms and managed unit.'},{status});}
 return NextResponse.json(input.name==='configure_rental_approval_policy'?{version:data}:data,{headers:{'Cache-Control':'no-store'}});
}
