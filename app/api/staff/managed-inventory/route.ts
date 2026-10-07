import {NextRequest,NextResponse} from 'next/server';
import {sameOrigin} from '@/lib/http/origin';
import {boundedText} from '@/lib/http/body';
import {catalogAccess} from '@/lib/staff/access';
import {managedInventoryInput} from '@/lib/staff/managed-inventory';
export async function POST(request:NextRequest){
 if(!sameOrigin(request))return NextResponse.json({error:'Invalid request origin.'},{status:403});
 if(!request.headers.get('content-type')?.includes('application/json'))return NextResponse.json({error:'JSON required.'},{status:415});
 const {client,user,membership}=await catalogAccess(['admin','realtor','manager']);if(!user)return NextResponse.json({error:'Verified staff sign-in required.'},{status:401});if(!membership)return NextResponse.json({error:'Managed inventory staff access required.'},{status:403});
 let body;try{body=await boundedText(request,12000);}catch{return NextResponse.json({error:'Request too large.'},{status:413});}
 let input;try{input=managedInventoryInput(JSON.parse(body));}catch(error){return NextResponse.json({error:error instanceof Error?error.message:'Invalid inventory request.'},{status:400});}
 const {data,error}=await client.rpc('author_managed_inventory',input);
 if(error){const status=error.code==='42501'?403:['40001','23505','40P01'].includes(error.code)?409:400;return NextResponse.json({error:status===409?'The inventory changed or the unit label is already used. Refresh before retrying.':status===403?'Private inventory access is unavailable. Listing linkage requires a catalog author.':'Unable to save. Check the fields, seller handoff and reserved/occupied unit protections.'},{status});}
 return NextResponse.json(data,{headers:{'Cache-Control':'no-store'}});
}
