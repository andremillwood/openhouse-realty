import {NextRequest,NextResponse} from 'next/server';
import {catalogAccess} from '@/lib/staff/access';
import {sameOrigin} from '@/lib/http/origin';
import {boundedText} from '@/lib/http/body';
import {invitationInput} from '@/lib/staff/invitation-validation';
const headers={'Cache-Control':'private, no-store'};
export async function POST(request:NextRequest){
 if(!sameOrigin(request))return NextResponse.json({error:'Invalid request origin.'},{status:403,headers});
 if(!request.headers.get('content-type')?.includes('application/json'))return NextResponse.json({error:'JSON required.'},{status:415,headers});
 const {client,user,membership}=await catalogAccess(['admin']);
 if(!user)return NextResponse.json({error:'Verified sign-in required.'},{status:401,headers});
 let body;try{body=await boundedText(request,4000);}catch{return NextResponse.json({error:'Request too large.'},{status:413,headers});}
 let input;try{input=invitationInput(JSON.parse(body));}catch(error){return NextResponse.json({error:error instanceof Error?error.message:'Check the invitation request.'},{status:400,headers});}
 if(['create','revoke'].includes(input.p_action)&&!membership)return NextResponse.json({error:'Organization administrator required.'},{status:403,headers});
 const {data,error}=await client.rpc('manage_staff_invitation',input);
 if(error){
  const status=error.code==='42501'?403:['40001','40P01','23505'].includes(error.code)?409:['22023','22P02','23503'].includes(error.code)?400:503;
  const message=status===503?'Invitation could not be saved. Retry the same request.':status===409?'Invitation changed, is already closed, or staff access already exists. Refresh before retrying.':'Check the current administrator approval, invited verified email, expiry, role and consent.';
  return NextResponse.json({error:message},{status,headers});
 }
 return NextResponse.json(data,{headers});
}
