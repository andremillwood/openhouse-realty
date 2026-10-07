const fs=require('fs'),ts=require('typescript'),assert=require('node:assert/strict');
let documents=[{id:'evidence',object_path:'invoice/evidence.pdf',claim_id:'lease'}],rpcError=null,removeError=null,markError=null,markResult=true,adminThrows=false,removeThrows=false,calls=[],removals=[],buckets=[];
const client={
 rpc:async(name,args)=>{calls.push({name,args});return name==='claim_expired_invoice_evidence'?{data:documents,error:rpcError}:{data:markResult,error:markError}},
 from(){throw Error('Direct marker write forbidden')},
 storage:{from:bucket=>{buckets.push(bucket);return {remove:async paths=>{removals.push(paths);if(removeThrows)throw Error('internal credential detail');return {error:removeError}}}}}
};
const m={exports:{}};new Function('require','exports','module',ts.transpileModule(fs.readFileSync('app/api/jobs/invoice-evidence/route.ts','utf8'),{compilerOptions:{module:ts.ModuleKind.CommonJS,target:ts.ScriptTarget.ES2022}}).outputText)(name=>{if(name==='node:crypto')return require(name);if(name==='next/server')return {NextResponse:{json:(body,options)=>new Response(JSON.stringify(body),options)}};if(name==='@/lib/supabase/admin')return {createAdminClient:()=>{if(adminThrows)throw Error('internal credential detail');return client}};if(name==='@/lib/finance/invoice-evidence')return {INVOICE_EVIDENCE_BUCKET:'vendor-invoice-evidence'};throw Error(name)},m.exports,m);
function request(value){return new Request('http://localhost/api/jobs/invoice-evidence',{headers:value===undefined?{}:{authorization:value}})}
async function checked(value,status){const response=await m.exports.GET(request(value));assert.equal(response.status,status);assert.equal(response.headers.get('Cache-Control'),'private, no-store');const body=await response.json();assert.doesNotMatch(JSON.stringify(body),/internal credential detail/);return body}
(async()=>{const savedCron=process.env.CRON_SECRET,savedKey=process.env.SUPABASE_SECRET_KEY;try{
 delete process.env.CRON_SECRET;await checked(undefined,401);process.env.CRON_SECRET='short';await checked('Bearer short',401);process.env.CRON_SECRET='c'.repeat(32);const auth='Bearer '+process.env.CRON_SECRET;
 await checked(undefined,401);await checked('Bearer wrong',401);await checked(auth.replace(/c$/,'x'),401);assert.equal(calls.length,0);
 delete process.env.SUPABASE_SECRET_KEY;await checked(auth,503);process.env.SUPABASE_SECRET_KEY='YOUR-'+'x'.repeat(40);await checked(auth,503);process.env.SUPABASE_SECRET_KEY='short';await checked(auth,503);assert.equal(calls.length,0);
 process.env.SUPABASE_SECRET_KEY='fixture-private-server-key-not-real-credential';adminThrows=true;await checked(auth,503);adminThrows=false;
 rpcError={message:'internal credential detail'};await checked(auth,503);assert.equal(removals.length,0);rpcError=null;
 removeError={};assert.deepEqual(await checked(auth,503),{purged:0,failed:1});assert.equal(calls.filter(c=>c.name==='mark_invoice_evidence_purged').length,0);removeError=null;
 removeThrows=true;await checked(auth,503);assert.equal(calls.filter(c=>c.name==='mark_invoice_evidence_purged').length,0);removeThrows=false;
 markError={message:'internal credential detail'};assert.deepEqual(await checked(auth,503),{purged:0,failed:1});markError=null;markResult=false;await checked(auth,503);markResult=true;
 assert.deepEqual(await checked(auth,200),{purged:1,failed:0});assert.deepEqual(calls.at(-1),{name:'mark_invoice_evidence_purged',args:{p_evidence_id:'evidence',p_claim_id:'lease'}});assert(buckets.every(bucket=>bucket==='vendor-invoice-evidence'));assert(removals.every(paths=>JSON.stringify(paths)==='["invoice/evidence.pdf"]'));
 documents=[];const before=removals.length;assert.deepEqual(await checked(auth,200),{purged:0,failed:0});assert.equal(removals.length,before);
 console.log('PASS: invoice cleanup cron/server credential gates, Storage-first removal, lease-bound RPC markers, safe failures and empty batches');
 }finally{if(savedCron===undefined)delete process.env.CRON_SECRET;else process.env.CRON_SECRET=savedCron;if(savedKey===undefined)delete process.env.SUPABASE_SECRET_KEY;else process.env.SUPABASE_SECRET_KEY=savedKey}})().catch(error=>{console.error(error);process.exitCode=1});
