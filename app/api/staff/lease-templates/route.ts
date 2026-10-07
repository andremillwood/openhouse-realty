import {NextRequest,NextResponse} from 'next/server';
import {sameOrigin} from '@/lib/http/origin';
import {boundedText} from '@/lib/http/body';
import {catalogAccess} from '@/lib/staff/access';
import {leaseTemplateInput} from '@/lib/leases/validation';
export async function POST(request:NextRequest){
 if(!sameOrigin(request))return NextResponse.json({error:'Invalid request origin.'},{status:403});
 if(!request.headers.get('content-type')?.includes('application/json'))return NextResponse.json({error:'JSON required.'},{status:415});
 const {client,user,membership}=await catalogAccess(['admin']);if(!user)return NextResponse.json({error:'Verified sign-in required.'},{status:401});if(!membership)return NextResponse.json({error:'Organization administrator required.'},{status:403});
 let input;try{input=leaseTemplateInput(JSON.parse(await boundedText(request,6000)));}catch{return NextResponse.json({error:'Check template key, version, approved source reference, fingerprint and business approval.'},{status:400});}
 const {data,error}=await client.rpc('register_approved_lease_template',input);if(error)return NextResponse.json({error:error.code==='40001'?'Template changed. Open its current version before registering an update.':'Unable to register this approved template reference.'},{status:error.code==='42501'?403:error.code==='40001'?409:400});
 return NextResponse.json(data,{headers:{'Cache-Control':'no-store'}});
}
