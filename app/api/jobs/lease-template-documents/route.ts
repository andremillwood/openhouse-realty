import {timingSafeEqual} from 'node:crypto';
import {NextRequest,NextResponse} from 'next/server';
import {createAdminClient} from '@/lib/supabase/admin';
import {LEASE_TEMPLATE_BUCKET} from '@/lib/leases/template-documents';
export const runtime='nodejs';
export const maxDuration=60;
const headers={'Cache-Control':'private, no-store'};
export async function GET(request:NextRequest){
 const secret=process.env.CRON_SECRET,authorization=Buffer.from(request.headers.get('authorization')||''),expected=Buffer.from(`Bearer ${secret}`);
 if(!secret||secret.length<32||authorization.length!==expected.length||!timingSafeEqual(authorization,expected))return NextResponse.json({error:'Unauthorized'},{status:401,headers});
 const key=process.env.SUPABASE_SECRET_KEY;
 if(!key||key.length<30||key.includes('YOUR-'))return NextResponse.json({error:'Legal document cleanup configuration incomplete.'},{status:503,headers});
 try{
  const client=createAdminClient(),{data:documents,error}=await client.rpc('claim_expired_lease_template_document');
  if(error)throw new Error();let purged=0,failed=0;
  for(const document of documents||[]){
   try{
    const {error:removeError}=await client.storage.from(LEASE_TEMPLATE_BUCKET).remove([document.object_path]);
    if(removeError){failed++;continue;}
    const {data:marked,error:markError}=await client.rpc('mark_lease_template_document_purged',{p_document_id:document.id,p_claim_id:document.claim_id});
    if(markError||marked!==true)failed++;else purged++;
   }catch{failed++;}
  }
  return NextResponse.json({purged,failed},{status:failed?503:200,headers});
 }catch{return NextResponse.json({error:'Legal document cleanup unavailable.'},{status:503,headers});}
}
