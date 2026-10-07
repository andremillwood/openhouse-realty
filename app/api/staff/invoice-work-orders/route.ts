import {NextRequest,NextResponse} from 'next/server';
import {catalogAccess} from '@/lib/staff/access';
const headers={'Cache-Control':'private, no-store'};
export async function GET(request:NextRequest) {
 const {client,user,membership}=await catalogAccess(['admin','finance']);
 if(!user)return NextResponse.json({error:'Verified sign-in required.'},{status:401,headers});
 if(!membership)return NextResponse.json({error:'Organization finance access required.'},{status:403,headers});
 const params=new URL(request.url).searchParams,property=params.get('property_id'),term=(params.get('q')||'').trim();
 if(!property||!/^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(property)||term.length>120)return NextResponse.json({error:'Check the selected property and search.'},{status:400,headers});
 const {data,error}=await client.rpc('search_invoice_work_orders',{p_property_id:property,p_term:term});
 if(error)return NextResponse.json({error:'Unable to search work-order labels.'},{status:error.code==='42501'?403:error.code==='22023'?400:503,headers});
 return NextResponse.json(data,{headers});
}
