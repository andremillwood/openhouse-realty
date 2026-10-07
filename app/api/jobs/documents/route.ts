import {timingSafeEqual} from 'node:crypto';
import {NextRequest,NextResponse} from 'next/server';
import {createAdminClient} from '@/lib/supabase/admin';
import {DOCUMENT_BUCKET} from '@/lib/documents/files';
export const runtime='nodejs';
export const maxDuration=60;
export async function GET(request:NextRequest){
 const secret=process.env.CRON_SECRET,authorization=Buffer.from(request.headers.get('authorization')||''),expected=Buffer.from(`Bearer ${secret}`);
 if(!secret||secret.length<32||authorization.length!==expected.length||!timingSafeEqual(authorization,expected))return NextResponse.json({error:'Unauthorized'},{status:401});
 if(!process.env.SUPABASE_SECRET_KEY)return NextResponse.json({error:'Document cleanup configuration incomplete.'},{status:503});
 try{const client=createAdminClient();const {data:documents,error}=await client.rpc('claim_expired_application_documents');if(error)throw new Error();let purged=0,failed=0;
 for(const document of documents||[]){const {error:removeError}=await client.storage.from(DOCUMENT_BUCKET).remove([document.object_path]);if(removeError){failed++;continue;}const {error:updateError}=await client.from('application_documents').update({purged_at:new Date().toISOString()}).eq('id',document.id).in('state',['expired','withdrawn']);if(updateError)failed++;else purged++;}
 return NextResponse.json({purged,failed},{status:failed?503:200,headers:{'Cache-Control':'no-store'}});
 }catch{return NextResponse.json({error:'Document cleanup unavailable.'},{status:503});}
}
