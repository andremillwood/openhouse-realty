const fs=require('fs'),ts=require('typescript'),assert=require('node:assert/strict');let user=null,membership=null,error=null,calls=[];
const client={rpc:async(name,args)=>{calls.push({name,args});return {data:{id:'created',state:'received',version:1},error}}},cache={};
function load(path){if(cache[path])return cache[path];const m={exports:{}},req=name=>{if(name==='next/server')return {NextResponse:{json:(body,options)=>new Response(JSON.stringify(body),options)}};if(name==='@/lib/staff/access')return {catalogAccess:async roles=>{assert.deepEqual(roles,['admin','finance']);return {client,user,membership}}};if(name.startsWith('@/lib/'))return load(name.slice(2)+'.ts');throw Error(name)};new Function('require','exports','module',ts.transpileModule(fs.readFileSync(path,'utf8'),{compilerOptions:{module:ts.ModuleKind.CommonJS,target:ts.ScriptTarget.ES2022}}).outputText)(req,m.exports,m);return cache[path]=m.exports;}
const {POST}=load('app/api/staff/cheque-postings/route.ts'),id='44556600-0000-4000-8000-000000000001',other='44556600-0000-4000-8000-000000000002',body={request_id:id,cheque_id:id,version:3,debit_account_id:id,credit_account_id:other,reason:'Approved cheque accounting',approved:true,organization_id:'spoof',amount_minor:1,posted_by:'spoof',journal_id:'spoof'};
function request(input,origin='http://127.0.0.1:3001',type='application/json'){return new Request('http://localhost:3001/api/staff/cheques',{method:'POST',headers:{host:'127.0.0.1:3001',origin,'Content-Type':type},body:JSON.stringify(input)})}
async function checked(input,status,origin,type){const response=await POST(request(input,origin,type));assert.equal(response.status,status);assert.equal(response.headers.get('Cache-Control'),'private, no-store');assert.doesNotMatch(JSON.stringify(await response.json()),/private database details/);}
(async()=>{
 await checked(body,401);await checked(body,403,'https://foreign.example');await checked(body,415,undefined,'text/plain');assert.equal(calls.length,0);
 user={id};await checked(body,403);assert.equal(calls.length,0);membership={organization_id:id,role:'finance'};await checked(body,200);
 assert.deepEqual(calls.at(-1),{name:'post_cleared_cheque',args:{p_request_id:id,p_cheque_id:id,p_expected_version:3,p_debit_account_id:id,p_credit_account_id:other,p_reason:'Approved cheque accounting',p_approved:true}});
 const count=calls.length;
 for(const invalid of [{approved:false},{credit_account_id:id},{version:2},{version:2147483647},{reason:'tiny'},{debit_account_id:'bad'}])await checked({...body,...invalid},400);
 await checked({...body,reason:'x'.repeat(6000)},413);assert.equal(calls.length,count);
 const reply=body;
 for(const [code,status] of [['42501',403],['40001',409],['40P01',409],['23505',409],['22023',400],['22P02',400],['23503',400],['XX000',503]]){error={code,message:'private database details'};await checked(reply,status);}
 console.log('PASS: cheque posting API verified finance access, origin/body/approval boundaries, distinct accounts/revisions, server-derived amount exclusion and safe private failures');
})().catch(error=>{console.error(error);process.exitCode=1});
