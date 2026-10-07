const fs=require('fs'),ts=require('typescript'),assert=require('node:assert/strict');
const queryModule={exports:{}};
new Function('exports','module',ts.transpileModule(fs.readFileSync('lib/enquiries/inbox-query.ts','utf8'),{compilerOptions:{module:ts.ModuleKind.CommonJS,target:ts.ScriptTarget.ES2022}}).outputText)(queryModule.exports,queryModule);
const {inboxQuery,inboxHref}=queryModule.exports;
assert.deepEqual(inboxQuery({status:['closed','new'],page:'-2'}),{status:'all',page:1});
assert.equal(inboxHref(inboxQuery({status:'contacted'}),2),'/staff/enquiries?status=contacted&page=2');
const source=ts.transpileModule(fs.readFileSync('app/staff/enquiries/page.tsx','utf8'),{compilerOptions:{module:ts.ModuleKind.CommonJS,jsx:ts.JsxEmit.ReactJSX,target:ts.ScriptTarget.ES2022}}).outputText;
async function run(params,{count=151,error=null,user={id:'staff'},membership={organization_id:'own-org'}}={}){
 const calls=[];
 const client={rpc:async(name)=>{calls.push(['rpc',name]);return {data:[],error:null}},from(table){let head=false;const builder={select(fields,options){head=options?.head;return builder},eq(...args){calls.push([table,'eq',...args]);return builder},order(){return builder},range(...args){calls.push([table,'range',...args]);return Promise.resolve({data:[],error:null})},then(resolve,reject){assert(head);return Promise.resolve({count,error}).then(resolve,reject)}};return builder}};
 const module={exports:{}};
 const req=name=>name==='@/lib/staff/access'?{catalogAccess:async()=>({client,user,membership})}:name==='@/lib/enquiries/inbox-query'?queryModule.exports:name==='next/navigation'?{redirect(url){throw {redirect:url}}}:name==='@/components/discovery/site-header'?{SiteHeader:()=>null}:name==='@/components/enquiries/staff-inbox'?{StaffInbox:()=>null}:require(name);
 new Function('require','exports','module',source)(req,module.exports,module);
 let redirect;try{await module.exports.default({searchParams:Promise.resolve(params)})}catch(e){if(!e.redirect)throw e;redirect=e.redirect}
 return {calls,redirect};
}
(async()=>{
 let result=await run({page:'5',status:'closed'});
 assert.deepEqual(result.calls.find(row=>row[1]==='range'),['enquiries','range',100,124]);
 assert.equal(result.calls.filter(row=>row[0]==='enquiries'&&row[1]==='eq'&&row[2]==='organization_id'&&row[3]==='own-org').length,2);
 assert.equal(result.calls.filter(row=>row[0]==='enquiries'&&row[1]==='eq'&&row[2]==='status'&&row[3]==='closed').length,2);
 result=await run({page:'99',status:'new'},{count:0});assert.equal(result.redirect,'/staff/enquiries?status=new');assert(!result.calls.some(row=>row[1]==='range'));
 result=await run({page:'9'},{error:{message:'offline'}});assert(!result.redirect);assert(!result.calls.some(row=>row[1]==='range'));
 result=await run({},{user:null});assert.equal(result.redirect,'/sign-in');assert.equal(result.calls.length,0);
 result=await run({},{membership:null});assert.equal(result.calls.length,0);
 console.log('PASS: whole-inbox status filters, organization-scoped pages beyond 100 records, empty/out-of-range handling and unauthorized query prevention');
})().catch(error=>{console.error(error);process.exitCode=1});
