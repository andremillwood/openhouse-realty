import { sameOrigin } from '@/lib/http/origin';
import { NextRequest,NextResponse } from 'next/server';
import { catalogAccess } from '@/lib/staff/access';
import { boundedText } from '@/lib/http/body';
import { staffEnquiryInput } from '@/lib/enquiries/staff-validation';
import { uuidPattern } from '@/lib/enquiries/validation';
export async function PATCH(request:NextRequest){
 if(!sameOrigin(request))return NextResponse.json({error:'Invalid request origin.'},{status:403});
 if(!request.headers.get('content-type')?.includes('application/json'))return NextResponse.json({error:'JSON required.'},{status:415});
 const {client,user,membership}=await catalogAccess(['admin','realtor','manager']);
 if(!user)return NextResponse.json({error:'Sign in first.'},{status:401});
 if(!membership)return NextResponse.json({error:'Staff access required.'},{status:403});
 let input;try{input=staffEnquiryInput(JSON.parse(await boundedText(request,10000)));}catch{return NextResponse.json({error:'Invalid enquiry update.'},{status:400});}
 if(input.action!=='status'){
  const {data,error}=await client.rpc('collaborate_enquiry',{p_enquiry_id:input.id,p_action:input.action,p_assignee_user_id:input.action==='assign'?input.assignee:null,p_expected_version:input.action==='assign'?input.version:null,p_request_id:input.action==='note'?input.requestId:null,p_body:input.action==='note'?input.body:null});
  if(error){const status=error.code==='42501'?403:error.code==='40001'?409:error.code==='P0001'?429:400;return NextResponse.json({error:status===409?'Another staff member changed the assignment. Refresh before retrying.':status===429?'Daily note limit reached.':'Unable to save this internal update. Check access and retry.'},{status});}
  return NextResponse.json(data,{headers:{'Cache-Control':'no-store'}});
 }
 const {data,error}=await client.from('enquiries').update({status:input.status}).eq('id',input.id).eq('organization_id',membership.organization_id).select('id').single();
 if(error||!data)return NextResponse.json({error:'Unable to update this enquiry. Check your access and retry.'},{status:400});
 return NextResponse.json({id:data.id},{headers:{'Cache-Control':'no-store'}});
}

export async function GET(request:NextRequest){
 const {client,user,membership}=await catalogAccess(['admin','realtor','manager']);
 if(!user)return NextResponse.json({error:'Sign in first.'},{status:401});
 if(!membership)return NextResponse.json({error:'Staff access required.'},{status:403});
 const id=request.nextUrl.searchParams.get('id')||'';const raw=request.nextUrl.searchParams.get('page')||'1';
 if(!uuidPattern.test(id)||!/^\d{1,4}$/.test(raw)||Number(raw)<1)return NextResponse.json({error:'Invalid history request.'},{status:400});
 const page=Number(raw);
 const {data:target,error:targetError}=await client.from('enquiries').select('id').eq('id',id).eq('organization_id',membership.organization_id).maybeSingle();
 if(targetError||!target)return NextResponse.json({error:'Enquiry unavailable.'},{status:404});
 const [{data:notes,error:noteError},{data:events,error:eventError}]=await Promise.all([
  client.from('enquiry_staff_notes').select('id,author_user_id,body,created_at').eq('organization_id',membership.organization_id).eq('enquiry_id',id).order('created_at',{ascending:false}).order('id').range((page-1)*25,page*25),
  client.from('enquiry_assignment_events').select('id,actor_user_id,previous_assignee_user_id,assignee_user_id,version,created_at').eq('organization_id',membership.organization_id).eq('enquiry_id',id).order('created_at',{ascending:false}).order('id').range((page-1)*25,page*25)
 ]);
 if(noteError||eventError)return NextResponse.json({error:'Unable to load staff history.'},{status:503});
 return NextResponse.json({notes:notes?.slice(0,25)||[],events:events?.slice(0,25)||[],hasMore:(notes?.length||0)>25||(events?.length||0)>25},{headers:{'Cache-Control':'no-store'}});
}
