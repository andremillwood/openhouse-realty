const fs=require('fs'),ts=require('typescript'),assert=require('node:assert/strict');
let currentUser=null,rpcError=null,rpcData={status:'saved',revision:'33445566-0000-4000-8000-000000000099'},calls=[],rpcThrows=false,authThrows=false;
const client={auth:{getUser:async()=>{if(authThrows)throw Error('Internal auth error');return {data:{user:currentUser},error:null}}},rpc:async(name,args)=>{if(rpcThrows)throw Error('Internal RPC error');calls.push({name,args});return{data:rpcData,error:rpcError};},from:()=>({select:()=>({eq:()=>({eq:()=>({maybeSingle:async()=>({data:{status:'requested'}})})})})})};
const cache={};function load(path){if(cache[path])return cache[path];const module={exports:{}};const req=name=>{
 if(name==='next/server')return{NextResponse:{json:(body,options)=>new Response(JSON.stringify(body),{...options,headers:{'Content-Type':'application/json',...options?.headers}})}};
 if(name==='@/lib/supabase/server')return{createClient:async()=>client};
 if(name.startsWith('@/lib/'))return load(name.slice(2)+'.ts');
 throw new Error(`Unexpected import ${name}`);
};new Function('require','exports','module',ts.transpileModule(fs.readFileSync(path,'utf8'),{compilerOptions:{module:ts.ModuleKind.CommonJS,target:ts.ScriptTarget.ES2022}}).outputText)(req,module.exports,module);cache[path]=module.exports;return module.exports;}
const {POST}=load('app/api/matching-preferences/route.ts');
const body={action:'save',revision:null,preferences:{intent:'buy',preferred_area:'Kingston',communication_style:'direct',guidance_style:'data-led',decision_pace:'decisive'},consent:true,user_id:'spoof',consented_at:'spoof'};
function request(data,origin='http://127.0.0.1:3001',contentType='application/json'){return new Request('http://localhost:3001/api/matching-preferences',{method:'POST',headers:{host:'127.0.0.1:3001',origin,'Content-Type':contentType},body:JSON.stringify(data)});}
(async()=>{
 assert.equal((await POST(request(body))).status,401);assert.equal(calls.length,0);
 assert.equal((await POST(request(body,'https://foreign.example'))).status,403);
 assert.equal((await POST(request(body,undefined,'text/plain'))).status,415);
 currentUser={id:'verified-test-user',email_confirmed_at:'2026-10-06T12:00:00Z'};
 let response=await POST(request(body));assert.equal(response.status,200);assert.equal(response.headers.get('Cache-Control'),'private, no-store');assert.equal(calls[0].name,'manage_matching_preferences');assert.deepEqual(Object.keys(calls[0].args).sort(),['p_action','p_consent','p_expected_revision','p_preferences']);
 for(const input of [null,[],{...body,revision:'bad'},{...body,action:'unknown'}])assert.equal((await POST(request(input))).status,400);
 assert.equal((await POST(request({...body,extra:'x'.repeat(3000)}))).status,413);
 rpcError={code:'40001',message:'Internal detail'};response=await POST(request(body));assert.equal(response.status,409);assert.doesNotMatch(JSON.stringify(await response.json()),/Internal detail/);
 rpcError=null;rpcData={status:'deleted',revision:null};response=await POST(request({...body,action:'delete'}));assert.equal(response.status,200);assert.equal(calls.at(-1).args.p_preferences,null);assert.equal(calls.at(-1).args.p_consent,false);
 for(const [code,status] of [['XX000',503],['42501',403],['22023',400]]){rpcError={code,message:'Private detail'};response=await POST(request(body));assert.equal(response.status,status);assert.equal(response.headers.get('Cache-Control'),'private, no-store');assert.doesNotMatch(JSON.stringify(await response.json()),/Private detail/);}rpcError=null;
 for(const malformed of [null,{}, {status:'saved',revision:'bad'},{status:'deleted',revision:null}]){rpcData=malformed;response=await POST(request(body));assert.equal(response.status,503);assert.equal(response.headers.get('Cache-Control'),'private, no-store');}
 rpcData={status:'saved',revision:'33445566-0000-4000-8000-000000000099',private_field:'hidden'};response=await POST(request(body));assert(!('private_field' in await response.json()));rpcThrows=true;assert.equal((await POST(request(body))).status,503);rpcThrows=false;authThrows=true;assert.equal((await POST(request(body))).status,503);authThrows=false;
 currentUser=null;response=await POST(request(body));assert.equal(response.headers.get('Cache-Control'),'private, no-store');
 console.log('PASS: preference API verified auth, origin/body guards, trusted arguments, deletion and safe revision conflict response');
})().catch(error=>{console.error(error);process.exit(1);});
