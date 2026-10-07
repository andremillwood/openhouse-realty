const fs=require('fs'),ts=require('typescript'),assert=require('node:assert/strict');
let currentUser=null,rpcError=null,rpcData='33445566-0000-4000-8000-000000000099',calls=[],rpcThrows=false,authThrows=false;
const client={auth:{getUser:async()=>{if(authThrows)throw Error('Internal auth error');return {data:{user:currentUser},error:null}}},rpc:async(name,args)=>{if(rpcThrows)throw Error('Internal RPC error');calls.push({name,args});return{data:rpcData,error:rpcError};},from:()=>({select:()=>({eq:()=>({eq:()=>({maybeSingle:async()=>({data:{status:'requested'}})})})})})};
const cache={};function load(path){if(cache[path])return cache[path];const module={exports:{}};const req=name=>{
 if(name==='next/server')return{NextResponse:{json:(body,options)=>new Response(JSON.stringify(body),{...options,headers:{'Content-Type':'application/json',...options?.headers}})}};
 if(name==='@/lib/supabase/server')return{createClient:async()=>client};
 if(name.startsWith('@/lib/'))return load(name.slice(2)+'.ts');
 throw new Error(`Unexpected import ${name}`);
};new Function('require','exports','module',ts.transpileModule(fs.readFileSync(path,'utf8'),{compilerOptions:{module:ts.ModuleKind.CommonJS,target:ts.ScriptTarget.ES2022}}).outputText)(req,module.exports,module);cache[path]=module.exports;return module.exports;}
const {POST}=load('app/api/enquiries/route.ts');
const id='33445566-0000-4000-8000-000000000099';
const body={request_id:id,realtor_id:id,listing_id:null,contact_name:'Client Name',phone:'',message:'Please introduce me to this realtor.',consent:true,user_id:'spoof',organization_id:'spoof',contact_email:'spoof@example.com'};
function request(data,origin='http://127.0.0.1:3001',type='application/json'){return new Request('http://localhost:3001/api/enquiries',{method:'POST',headers:{host:'127.0.0.1:3001',origin,'Content-Type':type},body:JSON.stringify(data)});}
async function check(input,status){const response=await POST(input);assert.equal(response.status,status);assert.equal(response.headers.get('Cache-Control'),'private, no-store');return response;}
(async()=>{
 await check(request(body),401);assert.equal(calls.length,0);await check(request(body,'https://foreign.example'),403);await check(request(body,undefined,'text/plain'),415);
 currentUser={id:'actual-user',email_confirmed_at:'2026-10-07T12:00:00Z'};
 const success=await check(request(body),201);assert.equal((await success.json()).id,id);assert.equal(calls[0].name,'submit_enquiry');assert.deepEqual(Object.keys(calls[0].args).sort(),['p_consent','p_contact_name','p_listing_id','p_message','p_phone','p_realtor_id','p_request_id']);assert.equal(calls[0].args.p_realtor_id,id);
 for(const invalid of [null,[],{...body,consent:false},{...body,listing_id:id},{...body,request_id:'bad'}])await check(request(invalid),400);
 await check(request({...body,message:'x'.repeat(13000)}),413);
 for(const [code,status] of [['P0001',429],['42501',401],['22023',400],['22P02',400],['XX000',503],['40001',503]]){rpcError={code,message:'Private database detail'};const result=await check(request(body),status);assert.doesNotMatch(JSON.stringify(await result.json()),/Private database detail/);}rpcError=null;
 for(const value of [null,{},[id],'bad']){rpcData=value;await check(request(body),503);}rpcData=id;
 rpcThrows=true;await check(request(body),503);rpcThrows=false;authThrows=true;await check(request(body),503);authThrows=false;
 currentUser={id:'unverified'};await check(request(body),401);
 console.log('PASS: enquiry API origin/auth/body guards, canonical identity-free arguments, private responses, UUID confirmation and safe uncertain failures');
})().catch(error=>{console.error(error);process.exitCode=1});
