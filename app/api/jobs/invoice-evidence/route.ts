import {timingSafeEqual} from 'node:crypto';
import {NextRequest,NextResponse} from 'next/server';
import {createAdminClient} from '@/lib/supabase/admin';
import {INVOICE_EVIDENCE_BUCKET} from '@/lib/finance/invoice-evidence';
export const runtime='nodejs';
export const maxDuration=60;
const headers={'Cache-Control':'private, no-store'};
export async function GET(request:NextRequest){
 const secret=process.env.CRON_SECRET,authorization=Buffer.from(request.headers.get('authorization')||''),expected=Buffer.from(`Bearer ${secret}`);
 if(!secret||secret.length<32||authorization.length!==expected.length||!timingSafeEqual(authorization,expected))return NextResponse.json({error:'Unauthorized'},{status:401,headers});
 const key=process.env.SUPABASE_SECRET_KEY;
 if(!key||key.length<30||key.includes('YOUR-'))return NextResponse.json({error:'Invoice evidence cleanup configuration incomplete.'},{status:503,headers});
 try{
  const client=createAdminClient(),{data:documents,error}=await client.rpc('claim_expired_invoice_evidence');
  if(error)throw new Error();let purged=0,failed=0;
  for(const document of documents||[]){
   try{
    const {error:removeError}=await client.storage.from(INVOICE_EVIDENCE_BUCKET).remove([document.object_path]);
    if(removeError){failed++;continue;}
    const {data:marked,error:markError}=await client.rpc('mark_invoice_evidence_purged',{p_evidence_id:document.id,p_claim_id:document.claim_id});
    if(markError||marked!==true)failed++;else purged++;
   }catch{failed++;}
  }
  return NextResponse.json({purged,failed},{status:failed?503:200,headers});
 }catch{return NextResponse.json({error:'Invoice evidence cleanup unavailable.'},{status:503,headers});}
}
