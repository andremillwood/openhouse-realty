const fs=require('fs'),ts=require('typescript'),assert=require('node:assert/strict'),{createHash}=require('node:crypto');
const id='55667788-0000-4000-8000-000000000001',org='55667788-0000-4000-8000-000000000002';
let user=null,membership=null,rpcError=null,readError=null,signError=null,downloadError=null,adminError=null,adminThrow=false,calls=[],storageCalls=[],reads=[],adminCalls=[],rolesSeen=[],reserved={id,path:'cheque/file.pdf',state:'reserved'};
const validBytes=Buffer.from('%PDF-1.7\nInvoice test fixture\n%%EOF');
let file=new Blob([validBytes],{type:'application/pdf'}),doc={id,user_id:id,object_path:'cheque/file.pdf',file_name:'bank.pdf',mime_type:'application/pdf',declared_size:validBytes.length,state:'reserved'};
const client={rpc:async(name,args)=>{calls.push({name,args});return {data:name==='reserve_cheque_evidence'?reserved:true,error:rpcError}},from:table=>{const query={table,fields:null,filters:[]};reads.push(query);const chain={select(fields){query.fields=fields;return chain},eq(key,value){query.filters.push([key,value]);return chain},async maybeSingle(){return {data:doc,error:readError}}};return chain},storage:{from:bucket=>({async createSignedUploadUrl(path,options){storageCalls.push({action:'upload',bucket,path,options});return {data:{token:'private-test-token'},error:signError}},async download(path){storageCalls.push({action:'read',bucket,path});return {data:file,error:downloadError}},async createSignedUrl(path,seconds,options){storageCalls.push({action:'download',bucket,path,seconds,options});return {data:{signedUrl:'https://example.invalid/private-file'},error:signError}}})}};
const cache={};function load(path){if(cache[path])return cache[path];const module={exports:{}};const req=name=>{if(name==='node:crypto')return require(name);if(name==='next/server')return {NextResponse:{json:(body,options)=>new Response(JSON.stringify(body),options)}};if(name==='@/lib/staff/access')return {catalogAccess:async roles=>{rolesSeen=roles;return {client,user,membership}}};if(name==='@/lib/supabase/admin')return {createAdminClient:()=>{if(adminThrow)throw Error('private credential detail');return {rpc:async(name,args)=>{adminCalls.push({name,args});return {data:true,error:adminError}}}}};if(name.startsWith('@/lib/'))return load(name.slice(2)+'.ts');throw Error(name)};new Function('require','exports','module',ts.transpileModule(fs.readFileSync(path,'utf8'),{compilerOptions:{module:ts.ModuleKind.CommonJS,target:ts.ScriptTarget.ES2022}}).outputText)(req,module.exports,module);return cache[path]=module.exports;}
const {POST,GET}=load('app/api/staff/cheque-evidence/route.ts');
const body={action:'reserve',request_id:id,cheque_id:id,kind:'deposit',file_name:' bank.pdf ',mime_type:'application/pdf',size:validBytes.length,user_id:'spoof',organization_id:'spoof',object_path:'spoof',sha256:'spoof'};
function post(input,origin='http://127.0.0.1:3001',type='application/json'){return new Request('http://localhost:3001/api/staff/cheque-evidence',{method:'POST',headers:{host:'127.0.0.1:3001',origin,'Content-Type':type},body:JSON.stringify(input)})}
function get(value=id){return {nextUrl:new URL('http://localhost/api/staff/cheque-evidence?id='+encodeURIComponent(value))}}
async function checked(response,status){assert.equal(response.status,status);assert.equal(response.headers.get('Cache-Control'),'private, no-store');const value=await response.json();assert.doesNotMatch(JSON.stringify(value),/private credential detail|internal database detail/);return value;}
(async()=>{
 const saved=process.env.SUPABASE_SECRET_KEY;try{
  await checked(await POST(post(body)),401);await checked(await GET(get()),401);assert.equal(calls.length,0);
  await checked(await POST(post(body,'https://foreign.example')),403);await checked(await POST(post(body,undefined,'text/plain')),415);
  user={id};await checked(await POST(post(body)),403);await checked(await GET(get()),403);
  membership={organization_id:org,role:'manager'};delete process.env.SUPABASE_SECRET_KEY;
  await checked(await POST(post(body)),503);assert.equal(calls.length,0);
  process.env.SUPABASE_SECRET_KEY='fixture-private-server-key-not-a-real-credential';
  await checked(await POST(post({...body,size:8388609})),400);await checked(await POST(post({...body,file_name:'x'.repeat(5000)})),413);assert.equal(calls.length,0);
  const result=await checked(await POST(post(body)),200);assert.equal(result.token,'private-test-token');assert.deepEqual(rolesSeen,['admin','finance']);
  assert.deepEqual(calls.at(-1),{name:'reserve_cheque_evidence',args:{p_cheque_id:id,p_request_id:id,p_kind:'deposit',p_file_name:'bank.pdf',p_mime_type:'application/pdf',p_size:validBytes.length}});
  assert.deepEqual(storageCalls.at(-1),{action:'upload',bucket:'cheque-bank-evidence',path:'cheque/file.pdf',options:{upsert:false}});
  signError={message:'internal database detail'};await checked(await POST(post(body)),503);signError=null;
  reserved.state='uploaded';const count=storageCalls.length;assert.deepEqual(await checked(await POST(post(body)),200),{id,state:'uploaded'});assert.equal(storageCalls.length,count);reserved.state='reserved';
  for(const [code,status] of [['42501',403],['23505',409],['40001',409],['40P01',409],['22023',400],['XX000',503]]){rpcError={code,message:'internal database detail'};await checked(await POST(post(body)),status)}rpcError=null;
  const action={action:'finish',id,user_id:'spoof',organization_id:'spoof',sha256:'spoof',size:1,mime_type:'spoof',object_path:'spoof'};
  doc=null;await checked(await POST(post(action)),404);doc={id,user_id:id,object_path:'cheque/file.pdf',file_name:'bank.pdf',mime_type:'application/pdf',declared_size:validBytes.length,state:'reserved'};
  readError={message:'internal database detail'};await checked(await POST(post(action)),503);readError=null;
  downloadError={message:'internal database detail'};await checked(await POST(post(action)),503);downloadError=null;
  file=new Blob(['wrong-size']);await checked(await POST(post(action)),400);assert.equal(adminCalls.length,0);
  file=new Blob([Buffer.alloc(validBytes.length)]);await checked(await POST(post(action)),400);assert.equal(adminCalls.length,0);
  file=new Blob([validBytes]);await checked(await POST(post(action)),200);
  assert.deepEqual(reads.at(-1).filters,[['id',id],['organization_id',org],['user_id',id]]);
  assert.deepEqual(adminCalls.at(-1),{name:'finish_cheque_evidence',args:{p_actor:id,p_evidence_id:id,p_size:validBytes.length,p_mime_type:'application/pdf',p_sha256:createHash('sha256').update(validBytes).digest('hex')}});
  adminError={code:'23505',message:'internal database detail'};await checked(await POST(post(action)),409);adminError=null;adminThrow=true;await checked(await POST(post(action)),503);adminThrow=false;
  doc.state='withdrawn';const readsBefore=storageCalls.length;await checked(await POST(post(action)),409);assert.equal(storageCalls.length,readsBefore);doc.state='reserved';
  delete process.env.SUPABASE_SECRET_KEY;await checked(await POST(post(action)),503);
  await checked(await POST(post({action:'withdraw',id,user_id:'spoof'})),200);assert.deepEqual(calls.at(-1),{name:'withdraw_cheque_evidence',args:{p_evidence_id:id}});
  await checked(await POST(post({action:'download',id})),400);
  await checked(await GET(get('invalid')),400);doc=null;await checked(await GET(get()),404);doc={object_path:'cheque/file.pdf',file_name:'bank.pdf',state:'uploaded'};
  const download=await checked(await GET(get()),200);assert.equal(download.expiresIn,120);
  assert.deepEqual(reads.at(-1).filters,[['id',id],['organization_id',org],['state','uploaded']]);
  assert.deepEqual(storageCalls.at(-1),{action:'download',bucket:'cheque-bank-evidence',path:'cheque/file.pdf',seconds:120,options:{download:'bank.pdf'}});
  signError={message:'internal database detail'};await checked(await GET(get()),503);
  console.log('PASS: cheque evidence API verified organization gates, closed credential paths, scoped reads, immutable uploads, server-derived byte certification and short private downloads');
 }finally{if(saved===undefined)delete process.env.SUPABASE_SECRET_KEY;else process.env.SUPABASE_SECRET_KEY=saved}
})().catch(error=>{console.error(error);process.exitCode=1});
