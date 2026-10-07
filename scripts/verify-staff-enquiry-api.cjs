const fs=require('fs'),ts=require('typescript'),assert=require('node:assert/strict');
let user=null,membership=null,rpcError=null,calls=[],target={id:'22334455-0000-4000-8000-000000000001'};
const client={rpc:async(name,args)=>{calls.push({name,args});return {data:{version:1},error:rpcError}},from(table){const builder={select(){return builder},update(){return builder},eq(){return builder},order(){return builder},range(){return Promise.resolve({data:Array.from({length:26},(_,i)=>({id:String(i)})),error:null})},maybeSingle:async()=>({data:target,error:null}),single:async()=>({data:target,error:null})};return builder}};
const cache={};function load(path){if(cache[path])return cache[path];const module={exports:{}};const req=name=>{
 if(name==='next/server')return {NextResponse:{json:(body,options)=>new Response(JSON.stringify(body),{...options,headers:{'Content-Type':'application/json',...options?.headers}})}};
 if(name==='@/lib/staff/access')return {catalogAccess:async()=>({client,user,membership})};
 if(name.startsWith('./'))return load(require('node:path').join(require('node:path').dirname(path),name)+'.ts');
 if(name.startsWith('@/lib/'))return load(name.slice(2)+'.ts');
 throw Error(`Unexpected import ${name}`);
};new Function('require','exports','module',ts.transpileModule(fs.readFileSync(path,'utf8'),{compilerOptions:{module:ts.ModuleKind.CommonJS,target:ts.ScriptTarget.ES2022}}).outputText)(req,module.exports,module);cache[path]=module.exports;return module.exports;}
const {PATCH,GET}=load('app/api/staff/enquiries/route.ts');const {staffEnquiryInput}=load('lib/enquiries/staff-validation.ts');
const id='22334455-0000-4000-8000-000000000001';
function request(body,origin='http://127.0.0.1:3001'){return new Request('http://localhost:3001/api/staff/enquiries',{method:'PATCH',headers:{host:'127.0.0.1:3001',origin,'Content-Type':'application/json'},body:JSON.stringify(body)});}
function get(query){const req=new Request(`http://localhost:3001/api/staff/enquiries?${query}`);req.nextUrl=new URL(req.url);return req;}
(async()=>{
 const assign={id,action:'assign',assignee:null,version:0,organization_id:'spoof',author_user_id:'spoof'};
 assert.deepEqual(staffEnquiryInput(assign),{id,action:'assign',assignee:null,version:0});
 for(const value of [-1,0.5,Infinity,2147483647])assert.throws(()=>staffEnquiryInput({...assign,version:value}));
 assert.throws(()=>staffEnquiryInput({...assign,assignee:'invalid'}));
 assert.throws(()=>staffEnquiryInput({id,action:'note',requestId:id,body:'x'}));
 assert.equal((await PATCH(request(assign))).status,401);assert.equal(calls.length,0);
 assert.equal((await PATCH(request(assign,'https://foreign.example'))).status,403);
 user={id};assert.equal((await PATCH(request(assign))).status,403);
 membership={organization_id:'real-org'};
 let response=await PATCH(request(assign));assert.equal(response.status,200);
 assert.deepEqual(calls.at(-1),{name:'collaborate_enquiry',args:{p_enquiry_id:id,p_action:'assign',p_assignee_user_id:null,p_expected_version:0,p_request_id:null,p_body:null}});
 rpcError={code:'40001',message:'database detail'};assert.equal((await PATCH(request(assign))).status,409);
 rpcError={code:'42501'};assert.equal((await PATCH(request(assign))).status,403);
 rpcError={code:'P0001'};assert.equal((await PATCH(request({id,action:'note',requestId:id,body:'Private note'}))).status,429);
 rpcError=null;response=await GET(get(`id=${id}`));assert.equal(response.status,200);const history=await response.json();assert.equal(history.notes.length,25);assert.equal(history.events.length,25);assert.equal(history.hasMore,true);assert.equal(response.headers.get('Cache-Control'),'no-store');
 assert.equal((await GET(get(`id=${id}&page=-1`))).status,400);
 target=null;assert.equal((await GET(get(`id=${id}`))).status,404);
 console.log('PASS: staff enquiry authentication/origin guards, trusted assignment arguments, version/note boundaries, conflict/permission/rate responses and private paged history');
})().catch(error=>{console.error(error);process.exitCode=1});
