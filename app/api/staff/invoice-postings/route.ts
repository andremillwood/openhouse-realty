import {NextRequest,NextResponse} from 'next/server';
import {catalogAccess} from '@/lib/staff/access';
import {sameOrigin} from '@/lib/http/origin';
import {boundedText} from '@/lib/http/body';
import {invoicePostingInput} from '@/lib/finance/invoice-posting';
const headers={'Cache-Control':'private, no-store'};
export async function POST(request:NextRequest){
 if(!sameOrigin(request))return NextResponse.json({error:'Invalid request origin.'},{status:403,headers});
 if(!request.headers.get('content-type')?.includes('application/json'))return NextResponse.json({error:'JSON required.'},{status:415,headers});
 const {client,user,membership}=await catalogAccess(['admin','finance']);
 if(!user)return NextResponse.json({error:'Verified sign-in required.'},{status:401,headers});
 if(!membership)return NextResponse.json({error:'Organization finance access required.'},{status:403,headers});
 let body;try{body=await boundedText(request,5000);}catch{return NextResponse.json({error:'Request too large.'},{status:413,headers});}
 let input;try{input=invoicePostingInput(JSON.parse(body));}catch(error){return NextResponse.json({error:error instanceof Error?error.message:'Check the invoice details.'},{status:400,headers});}
 const {data,error}=await client.rpc('post_approved_vendor_invoice',input);
 if(error){
  const status=error.code==='42501'?403:['40001','40P01','23505'].includes(error.code)?409:['22023','22P02','23503'].includes(error.code)?400:503;
  const message=status===503?'Invoice posting could not be confirmed. Retry the same request.':status===409?'Invoice changed or already has a posting. Refresh before retrying.':'Check the approved revision, approved organization accounts and explicit accounting approval.';
  return NextResponse.json({error:message},{status,headers});
 }
 return NextResponse.json({journal_id:data},{headers});
}
