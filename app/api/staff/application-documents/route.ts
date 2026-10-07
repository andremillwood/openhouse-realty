import {NextRequest,NextResponse} from 'next/server';
import {sameOrigin} from '@/lib/http/origin';
import {boundedText} from '@/lib/http/body';
import {createClient} from '@/lib/supabase/server';
import {documentReviewInput} from '@/lib/applications/document-review';
export async function POST(request:NextRequest){
 if(!sameOrigin(request))return NextResponse.json({error:'Invalid request origin.'},{status:403});
 if(!request.headers.get('content-type')?.includes('application/json'))return NextResponse.json({error:'JSON required.'},{status:415});
 const client=await createClient();const {data:{user},error:authError}=await client.auth.getUser();if(authError||!user?.email_confirmed_at)return NextResponse.json({error:'Sign in with a verified staff account.'},{status:401});
 let body;try{body=await boundedText(request,12000);}catch{return NextResponse.json({error:'Request too large.'},{status:413});}
 let input;try{input=documentReviewInput(JSON.parse(body));}catch(error){return NextResponse.json({error:error instanceof Error?error.message:'Invalid review.'},{status:400});}
 const {data,error}=await client.rpc('review_application_document',input);
 if(error){const status=error.code==='42501'?403:error.code==='40001'?409:error.code==='P0001'?429:400;return NextResponse.json({error:status===409?'Document review changed. Refresh before recording your decision.':status===403?'Independent staff access to this application is required.':status===429?'Daily review limit reached.':'Review requires an uploaded document and application under review.'},{status});}
 return NextResponse.json(data,{headers:{'Cache-Control':'no-store'}});
}
export async function GET(request:NextRequest){
 const client=await createClient();const {data:{user},error:authError}=await client.auth.getUser();if(authError||!user?.email_confirmed_at)return NextResponse.json({error:'Sign in with a verified staff account.'},{status:401});
 const id=request.nextUrl.searchParams.get('id')||'',raw=request.nextUrl.searchParams.get('page')||'1';
 if(!/^[a-f\d]{8}-(?:[a-f\d]{4}-){3}[a-f\d]{12}$/i.test(id)||!/^\d{1,5}$/.test(raw)||Number(raw)<1)return NextResponse.json({error:'Invalid document history request.'},{status:400});
 const {data:review,error:reviewError}=await client.from('application_document_reviews').select('document_id').eq('document_id',id).maybeSingle();
 if(reviewError)return NextResponse.json({error:'Document history unavailable.'},{status:503});if(!review)return NextResponse.json({error:'Document history unavailable.'},{status:404});
 const page=Number(raw);const {data:events,error}=await client.from('application_document_review_events').select('id,old_status,new_status,reason,version,created_at').eq('document_id',id).order('created_at',{ascending:false}).order('id').range((page-1)*25,page*25);
 if(error)return NextResponse.json({error:'Unable to load document history.'},{status:503});
 return NextResponse.json({events:(events||[]).slice(0,25),hasMore:(events?.length||0)>25},{headers:{'Cache-Control':'no-store'}});
}
