import {NextRequest,NextResponse} from 'next/server';
import {catalogAccess} from '@/lib/staff/access';
import {sameOrigin} from '@/lib/http/origin';
import {boundedText} from '@/lib/http/body';
import {preventivePlanInput} from '@/lib/staff/preventive-plan-validation';
const headers={'Cache-Control':'private, no-store'};
export async function POST(request:NextRequest){
 if(!sameOrigin(request))return NextResponse.json({error:'Invalid request origin.'},{status:403,headers});
 if(!request.headers.get('content-type')?.includes('application/json'))return NextResponse.json({error:'JSON required.'},{status:415,headers});
 const {client,user,membership}=await catalogAccess(['admin','manager']);
 if(!user)return NextResponse.json({error:'Verified sign-in required.'},{status:401,headers});
 if(!membership)return NextResponse.json({error:'Organization management access required.'},{status:403,headers});
 let body;try{body=await boundedText(request,10000);}catch{return NextResponse.json({error:'Request too large.'},{status:413,headers});}
 let input;try{input=preventivePlanInput(JSON.parse(body));}catch(error){return NextResponse.json({error:error instanceof Error?error.message:'Check the preventive plan.'},{status:400,headers});}
 const {data,error}=input.p_action==='skip'?await client.rpc('skip_preventive_occurrence',{p_request_id:input.p_request_id,p_plan_id:input.p_plan_id,p_expected_version:input.p_expected_version,p_reason:input.p_reason,p_approved:input.p_approved}):await client.rpc('manage_preventive_plan',input);
 if(error){const status=error.code==='42501'?403:['40001','40P01','23505'].includes(error.code)?409:['P0201','22023','22P02','23503'].includes(error.code)?400:503;
 return NextResponse.json({error:error.code==='P0201'?'Choose a next due date after the latest issued or skipped occurrence. Review the plan history before retrying.':status===503?'Plan result could not be confirmed. Retry the same request.':status===409?'Refresh the plan. Check its revision, active due date and creation limits before retrying.':'Check the approved scope, organization location and management access.'},{status,headers});}
 const uuid=/^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
 if((input.p_action==='skip'&&data?.work_order_id!=null)||!data||typeof data.id!=='string'||!uuid.test(data.id)||!Number.isInteger(data.version)||data.version<1||(data.work_order_id!=null&&(typeof data.work_order_id!=='string'||!uuid.test(data.work_order_id)))||(input.p_action==='issue'&&(typeof data.work_order_id!=='string'||!uuid.test(data.work_order_id))))return NextResponse.json({error:'Plan result could not be confirmed. Retry the same request.'},{status:503,headers});
 return NextResponse.json(data,{headers});
}
