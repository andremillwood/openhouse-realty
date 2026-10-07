const fs=require('fs'),ts=require('typescript'),assert=require('node:assert/strict');
let user=null,membership=null,rpcError=null,calls=[];
const client={auth:{getUser:async()=>({data:{user},error:null})},rpc:async(name,args)=>{calls.push({name,args});return {data:'44556677-0000-4000-8000-000000000099',error:rpcError}}};
const cache={};function load(path){if(cache[path])return cache[path];const module={exports:{}};const req=name=>{
 if(name==='next/server')return {NextResponse:{json:(body,options)=>new Response(JSON.stringify(body),{...options,headers:{'Content-Type':'application/json',...options?.headers}})}};
 if(name==='@/lib/supabase/server')return {createClient:async()=>client};
 if(name==='@/lib/staff/access')return {catalogAccess:async()=>({client,user,membership})};
 if(name.startsWith('@/lib/'))return load(name.slice(2)+'.ts');
 throw Error(`Unexpected import ${name}`);
};new Function('require','exports','module',ts.transpileModule(fs.readFileSync(path,'utf8'),{compilerOptions:{module:ts.ModuleKind.CommonJS,target:ts.ScriptTarget.ES2022}}).outputText)(req,module.exports,module);cache[path]=module.exports;return module.exports;}
const {POST}=load('app/api/sellers/route.ts'),{PATCH,POST:HANDOFF}=load('app/api/staff/sellers/route.ts'),{sellerInput,sellerTransition,sellerHandoff}=load('lib/sellers/validation.ts');
const id='44556677-0000-4000-8000-000000000001';
const body={request_id:id,realtor_id:id,name:'Test Seller',phone:'',property_address:'Private test address',area:'Kingston',property_type:'house',seller_intent:'considering',message:'Please review this property.',consent:true,user_id:'spoof',email:'spoof@example.invalid',organization_id:'spoof',status:'listed'};
function request(data,method='POST',origin='http://127.0.0.1:3001'){return new Request('http://localhost:3001/api/sellers',{method,headers:{host:'127.0.0.1:3001',origin,'Content-Type':'application/json'},body:JSON.stringify(data)});}
(async()=>{
 const parsed=sellerInput(body);assert.equal(parsed.user_id,undefined);assert.equal(parsed.email,undefined);assert.equal(parsed.organization_id,undefined);assert.equal(parsed.status,undefined);
 for(const bad of [{consent:false},{realtor_id:'invalid'},{property_address:'x'},{property_type:'invented'},{seller_intent:'invented'},{message:'x'.repeat(2001)}])assert.throws(()=>sellerInput({...body,...bad}));
 assert.throws(()=>sellerTransition({id,status:'listed',expected_status:'proposal',reason:'Publish directly.'}));
 assert.equal((await POST(request(body))).status,401);assert.equal(calls.length,0);
 assert.equal((await POST(request(body,'POST','https://foreign.example'))).status,403);
 user={id,email_confirmed_at:null};assert.equal((await POST(request(body))).status,401);
 user={id,email_confirmed_at:'2026-10-06T12:00:00Z'};let response=await POST(request(body));assert.equal(response.status,201);assert.deepEqual(calls.at(-1),{name:'submit_seller_request',args:parsed});assert.equal(response.headers.get('Cache-Control'),'no-store');
 rpcError={code:'P0001'};assert.equal((await POST(request(body))).status,429);
 rpcError={code:'42501'};assert.equal((await POST(request(body))).status,403);
 const change={id,status:'contacted',expected_status:'new',reason:'Shared follow-up.'};assert.equal((await PATCH(request(change,'PATCH'))).status,403);
 membership={organization_id:'actual-org'};rpcError=null;assert.equal((await PATCH(request(change,'PATCH'))).status,200);assert.deepEqual(calls.at(-1),{name:'transition_seller_request',args:{p_id:id,p_status:'contacted',p_expected_status:'new',p_reason:'Shared follow-up.'}});
 rpcError={code:'40001'};assert.equal((await PATCH(request(change,'PATCH'))).status,409);
 rpcError={code:'42501'};assert.equal((await PATCH(request(change,'PATCH'))).status,403);
 const handoff={id,request_id:id,public_title:'Approved public title',public_area:'Kingston',property_type:'house',approval_reason:'Seller authorized draft preparation.',seller_approved:true,organization_id:'spoof',property_address:'Should not be copied'};
 assert.throws(()=>sellerHandoff({...handoff,seller_approved:false}));assert.throws(()=>sellerHandoff({...handoff,property_type:'other'}));
 const approved=sellerHandoff(handoff);assert.equal(approved.property_address,undefined);assert.equal(approved.organization_id,undefined);
 rpcError=null;response=await HANDOFF(request(handoff));assert.equal(response.status,201);assert.deepEqual(calls.at(-1),{name:'prepare_seller_listing',args:approved});
 rpcError={code:'P0001'};assert.equal((await HANDOFF(request(handoff))).status,409);rpcError={code:'42501'};assert.equal((await HANDOFF(request(handoff))).status,403);
 console.log('PASS: seller input/consent bounds, ignored identity/routing/status spoofing, origin/verified-auth guards, trusted RPC arguments and staff stage conflict responses');
})().catch(error=>{console.error(error);process.exitCode=1});
