import {NextRequest,NextResponse} from 'next/server';
import {sameOrigin} from '@/lib/http/origin';
import {boundedText} from '@/lib/http/body';
import {catalogAccess} from '@/lib/staff/access';
import {leasePreparationInput} from '@/lib/leases/validation';
export async function POST(request:NextRequest){
 if(!sameOrigin(request))return NextResponse.json({error:'Invalid request origin.'},{status:403});
 if(!request.headers.get('content-type')?.includes('application/json'))return NextResponse.json({error:'JSON required.'},{status:415});
 const {client,user,membership}=await catalogAccess(['admin','realtor','manager']);if(!user)return NextResponse.json({error:'Verified staff sign-in required.'},{status:401});if(!membership)return NextResponse.json({error:'Organization staff required.'},{status:403});
 let body;try{body=await boundedText(request,6000);}catch{return NextResponse.json({error:'Request too large.'},{status:413});}
 let input;try{input=leasePreparationInput(JSON.parse(body));}catch(error){return NextResponse.json({error:error instanceof Error?error.message:'Check lease terms.'},{status:400});}
 const {data,error}=await client.rpc('prepare_rental_lease_draft',input);
 if(error){const status=error.code==='42501'?403:['40001','23505','40P01'].includes(error.code)?409:400;return NextResponse.json({error:status===403?'Independent organization staff and an approved organization template are required.':status===409?'The application, draft or template changed. Refresh before retrying.':'Draft checks are incomplete. Confirm current approval, held unit, verified participant contacts and approved terms.'},{status});}
 return NextResponse.json(data,{headers:{'Cache-Control':'no-store'}});
}
