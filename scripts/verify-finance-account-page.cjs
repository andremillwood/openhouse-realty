const fs=require('fs'),ts=require('typescript'),assert=require('node:assert/strict'),React=require('react'),{renderToStaticMarkup}=require('react-dom/server');
const source=ts.transpileModule(fs.readFileSync('app/staff/finance/accounts/page.tsx','utf8'),{compilerOptions:{module:ts.ModuleKind.CommonJS,jsx:ts.JsxEmit.ReactJSX,target:ts.ScriptTarget.ES2022}}).outputText;
async function run(input={},options={}) {
 const calls=[];let editor=0;const user=options.user===null?null:{id:'staff'},membership=options.membership===null?null:{organization_id:'own',role:options.role||'admin'};
 const client={from(table){assert.equal(table,'finance_accounts');let head=false;const b={select(fields,o){head=o.head;return b},eq(...a){calls.push(['eq',...a]);return b},order(...a){calls.push(['order',...a]);return b},range(...a){calls.push(['range',...a]);return Promise.resolve({data:[],error:options.rowError})},then(resolve,reject){assert(head);return Promise.resolve({count:options.count??62,error:options.countError}).then(resolve,reject)}};return b;}};
 const m={exports:{}};new Function('require','exports','module',source)(name=>name==='@/lib/staff/access'?{catalogAccess:async roles=>{assert.deepEqual(roles,['admin','finance']);return {client,user,membership}}}:name==='next/navigation'?{redirect(url){throw {redirect:url}},notFound(){throw {notFound:true}}}:name==='@/components/discovery/site-header'?{SiteHeader:()=>null}:name==='@/components/finance/account-editor'?{FinanceAccountEditor:()=>{editor++;return React.createElement('div',null,'Account editor')}}:require(name),m.exports,m);
 let html,error;try{html=renderToStaticMarkup(await m.exports.default({searchParams:Promise.resolve(input)}))}catch(e){error=e}return {html,error,calls,editor};
}
(async()=>{
 let r=await run({page:'3',organization_id:'foreign'});assert(!r.error);assert.equal(r.editor,1);assert.equal(r.calls.filter(c=>c[0]==='eq'&&c[1]==='organization_id'&&c[2]==='own').length,2);assert.deepEqual(r.calls.find(c=>c[0]==='range'),['range',50,74]);assert.match(r.html,/Page 3 of 3/);
 r=await run({}, {role:'finance'});assert.equal(r.editor,0);assert.match(r.html,/Finance staff can review/);
 r=await run({page:'999'},{count:0});assert.equal(r.error.redirect,'/staff/finance/accounts?page=1');assert(!r.calls.some(c=>c[0]==='range'));
 r=await run({}, {user:null});assert.equal(r.error.redirect,'/sign-in');assert.equal(r.calls.length,0);
 r=await run({}, {membership:null});assert(r.error.notFound);assert.equal(r.calls.length,0);
 r=await run({}, {countError:{message:'offline'}});assert(r.error instanceof Error);assert(!r.calls.some(c=>c[0]==='range'));
 r=await run({}, {rowError:{message:'offline'}});assert.match(r.html,/Unable to load accounts/);
 console.log('PASS: finance account page organization scope, administrator editor gate, finance read-only view, pagination and denied/failure paths');
})().catch(e=>{console.error(e);process.exitCode=1});
