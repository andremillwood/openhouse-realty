const fs=require('fs'),ts=require('typescript'),assert=require('node:assert/strict');
let user=null,membership=null,accessFailure=false,error=null,throwRpc=false,calls=[];
const id='66117788-0000-4000-8000-000000000001';let data={id,signing_id:id,state:'withdrawn'};
const client={rpc:async(name,args)=>{calls.push({name,args});if(throwRpc)throw Error('private transport');return {data,error}}};const cache={};
function load(path){if(cache[path])return cache[path];const m={exports:{}};new Function('require','exports','module',ts.transpileModule(fs.readFileSync(path,'utf8'),{compilerOptions:{module:ts.ModuleKind.CommonJS,target:ts.ScriptTarget.ES2022}}).outputText)(name=>name==='next/server'?{NextResponse:{json:(body,options)=>new Response(JSON.stringify(body),options)}}:name==='@/lib/staff/access'?{catalogAccess:async roles=>{assert.deepEqual(roles,['admin','realtor','manager']);if(accessFailure)throw Error('private auth');return {client,user,membership}}}:name.startsWith('@/lib/')?load(name.slice(2)+'.ts'):require(name),m.exports,m);return cache[path]=m.exports;}
const {POST}=load('app/api/staff/lease-signing/withdraw/route.ts');
const body={signing_id:id,request_id:id,reason:'Approved withdrawal reason',approved:true};
const request=(value=body,origin='http://127.0.0.1:3001',type='application/json')=>new Request('http://localhost:3001/api/staff/lease-summaries',{method:'POST',headers:{host:'127.0.0.1:3001',origin,'Content-Type':type},body:JSON.stringify(value)});
async function check(status,value=body,origin,type){const r=await POST(request(value,origin,type));assert.equal(r.status,status);assert.equal(r.headers.get('Cache-Control'),'private, no-store');const result=await r.json();assert(!JSON.stringify(result).includes('private'));return result;}
(async()=>{
 await check(401);await check(403,body,'https://foreign.example');await check(415,body,undefined,'text/plain');user={id};await check(403);membership={organization_id:id,role:'manager'};
 const result=await check(200);assert.deepEqual(result,data);assert.deepEqual(calls.at(-1),{name:'withdraw_rental_lease_signing',args:{p_signing_id:id,p_request_id:id,p_reason:body.reason,p_approved:true}});
 const n=calls.length;await check(413,{...body,extra:'x'.repeat(4000)});for(const change of [{approved:false},{signing_id:'bad'},{reason:'x'},{request_id:'bad'},{reason:'   '}])await check(400,{...body,...change});await check(400,{...body,organization_id:'spoof'});await check(400,{...body,state:'signed'});assert.equal(calls.length,n);
 for(const [code,status] of [['42501',403],['40001',409],['23505',409],['40P01',409],['22023',400],['XX000',503]]){error={code,message:'private database'};await check(status);}error=null;
 for(const invalid of [null,{...data,id:'bad'},{...data,signing_id:'foreign'},{...data,state:'signed'}]){data=invalid;await check(503);}throwRpc=true;await check(503);throwRpc=false;accessFailure=true;await check(503);
 console.log('PASS: signing withdrawal role/origin/body/approval gates, rejected authority fields, conflict/uncertainty errors and pending receipt binding');
})().catch(error=>{console.error(error);process.exitCode=1});
