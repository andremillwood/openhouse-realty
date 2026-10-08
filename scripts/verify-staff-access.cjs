const fs=require('fs'),ts=require('typescript'),assert=require('node:assert/strict');
async function run(options={}){
 const calls=[];
 const user=options.user===null?null:{id:'verified',email_confirmed_at:'2026-10-08',is_anonymous:false,...options.user};
 const client={auth:{getUser:async()=>({data:{user},error:options.authError||null})},from(table){calls.push(['from',table]);return {select(columns){calls.push(['select',columns]);return this},eq(key,value){calls.push(['eq',key,value]);return this},single:async()=>({data:options.membership===null?null:{organization_id:'own',role:'admin',...options.membership},error:options.membershipError||null})}}};
 const m={exports:{}};
 new Function('require','exports','module',ts.transpileModule(fs.readFileSync('lib/staff/access.ts','utf8'),{compilerOptions:{module:ts.ModuleKind.CommonJS,target:ts.ScriptTarget.ES2022}}).outputText)(n=>n==='server-only'?{}:n==='@/lib/supabase/server'?{createClient:async()=>client}:require(n),m.exports,m);
 return {result:await m.exports.catalogAccess(options.roles),calls};
}
(async()=>{
 for(const options of [{user:null},{user:{email_confirmed_at:null}},{user:{is_anonymous:true}},{authError:{message:'invalid'}}]){const {result,calls}=await run(options);assert.equal(result.user,null);assert.equal(result.membership,null);assert.equal(calls.length,0);}
 for(const options of [{membershipError:{message:'unavailable'}},{membership:null},{membership:{organization_id:null}},{membership:{role:'finance'}}]){const {result}=await run(options);assert.equal(result.membership,null);}
 const {result,calls}=await run();assert.equal(result.membership.role,'admin');assert.deepEqual(calls,[['from','staff_accounts'],['select','organization_id,role'],['eq','user_id','verified']]);
 assert.equal((await run({roles:['finance'],membership:{role:'finance'}})).result.membership.role,'finance');
 console.log('PASS: actual shared staff helper denies anonymous/unverified/failed sessions before membership reads and binds allowed roles to verified identity');
})().catch(error=>{console.error(error);process.exitCode=1});
