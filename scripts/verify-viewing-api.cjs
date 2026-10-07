const fs=require('fs'),ts=require('typescript'),assert=require('node:assert/strict');
let currentUser=null,rpcError=null,rpcData='33445566-0000-4000-8000-000000000099',calls=[],stored={status:'requested'},storedError=null,rpcThrows=false;
const client={auth:{getUser:async()=>({data:{user:currentUser},error:null})},rpc:async(name,args)=>{if(rpcThrows)throw Error('Private transport error');calls.push({name,args});return{data:rpcData,error:rpcError};},from:()=>({select:()=>({eq:()=>({eq:()=>({maybeSingle:async()=>({data:stored,error:storedError})})})})})};
const cache={};function load(path){if(cache[path])return cache[path];const module={exports:{}};const req=name=>{
 if(name==='next/server')return{NextResponse:{json:(body,options)=>new Response(JSON.stringify(body),{...options,headers:{'Content-Type':'application/json',...options?.headers}})}};
 if(name==='@/lib/supabase/server')return{createClient:async()=>client};
 if(name.startsWith('@/lib/'))return load(name.slice(2)+'.ts');
 throw new Error(`Unexpected import ${name}`);
};new Function('require','exports','module',ts.transpileModule(fs.readFileSync(path,'utf8'),{compilerOptions:{module:ts.ModuleKind.CommonJS,target:ts.ScriptTarget.ES2022}}).outputText)(req,module.exports,module);cache[path]=module.exports;return module.exports;}
const {POST,PATCH}=load('app/api/viewings/route.ts');
const body={request_id:'33445566-0000-4000-8000-000000000015',slot_id:'33445566-0000-4000-8000-000000000010',contact_name:'Test Person',phone:'',consent:true,user_id:'spoof',email:'spoof@example.invalid'};
function request(data,method='POST',origin='http://127.0.0.1:3001'){return new Request('http://localhost:3001/api/viewings',{method,headers:{host:'127.0.0.1:3001',origin,'Content-Type':'application/json'},body:JSON.stringify(data)});}
(async()=>{
 assert.equal((await POST(request(body))).status,401);assert.equal(calls.length,0);
 assert.equal((await POST(request(body,'POST','https://foreign.example'))).status,403);
 currentUser={id:'verified-test-user',email_confirmed_at:'2026-10-06T12:00:00Z'};
 let response=await POST(request(body));assert.equal(response.status,201);assert.equal((await response.json()).status,'requested');assert.equal(calls[0].name,'request_viewing');assert.equal(calls[0].args.user_id,undefined);assert.equal(calls[0].args.email,undefined);
 rpcError={code:'P0001',message:'Internal database details'};assert.equal((await POST(request(body))).status,409);
 for(const code of ['23505','40001','40P01']){rpcError={code,message:'Internal database details'};response=await POST(request(body));assert.equal(response.status,409);const payload=JSON.stringify(await response.json());assert.match(payload,/open-house RSVP/);assert.doesNotMatch(payload,/Internal database details/);}
 rpcError={code:'42501'};assert.equal((await PATCH(request({viewing_id:body.slot_id,action:'confirm',reason:''},'PATCH'))).status,403);
 rpcError=null;rpcData='expired';response=await PATCH(request({viewing_id:body.slot_id,action:'cancel',reason:'Plans changed'},'PATCH'));assert.equal(response.status,409);assert.equal((await response.json()).status,'expired');
 rpcData='cancelled';assert.equal((await PATCH(request({viewing_id:body.slot_id,action:'cancel',reason:'Plans changed'},'PATCH'))).status,200);
 const count=calls.length;assert.equal((await POST(request({...body,consent:false}))).status,400);assert.equal(calls.length,count);
 rpcError=null;rpcData='33445566-0000-4000-8000-000000000099';
 for(const value of [null,{status:'unknown'}]){stored=value;response=await POST(request(body));assert.equal(response.status,503);assert.equal(response.headers.get('Cache-Control'),'private, no-store');}stored={status:'requested'};
 storedError={message:'Private read error'};assert.equal((await POST(request(body))).status,503);storedError=null;
 rpcData=null;assert.equal((await POST(request(body))).status,503);rpcData='33445566-0000-4000-8000-000000000099';
 rpcError={code:'XX000',message:'Private database error'};response=await POST(request(body));assert.equal(response.status,503);assert.doesNotMatch(JSON.stringify(await response.json()),/Private database error/);rpcError=null;
 rpcThrows=true;assert.equal((await POST(request(body))).status,503);rpcThrows=false;
 console.log('PASS: viewing API origin/auth guards, trusted RPC arguments, capacity conflicts, staff authorization errors, committed expiry response and cancellation');
})().catch(error=>{console.error(error);process.exit(1);});
