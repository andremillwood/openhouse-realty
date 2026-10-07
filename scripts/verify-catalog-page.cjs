const fs = require('fs');
const ts = require('typescript');
const assert = require('node:assert/strict');
const source = ts.transpileModule(fs.readFileSync('app/listings/page.tsx','utf8'), {compilerOptions:{module:ts.ModuleKind.CommonJS,jsx:ts.JsxEmit.ReactJSX,target:ts.ScriptTarget.ES2022}}).outputText;
const queryModule = {exports:{}};
new Function('exports','module',ts.transpileModule(fs.readFileSync('lib/discovery/catalog-query.ts','utf8'),{compilerOptions:{module:ts.ModuleKind.CommonJS,target:ts.ScriptTarget.ES2022}}).outputText)(queryModule.exports,queryModule);
async function run(params,count,countError=null) {
  const calls=[];
  const client={auth:{getUser:async()=>({data:{user:null}})},from(table){assert.equal(table,'listings');let head=false;const builder={select(fields,options){head=options.head;calls.push(['select',head]);return builder},eq(...args){calls.push(['eq',...args]);return builder},ilike(...args){calls.push(['ilike',...args]);return builder},or(...args){calls.push(['or',...args]);return builder},order(){return builder},range(start,end){calls.push(['range',start,end]);return Promise.resolve({data:[],error:null})},then(resolve,reject){assert(head);return Promise.resolve({count,error:countError}).then(resolve,reject)}};return builder}};
  const module={exports:{}};
  const mockRequire=name=>name==='@/lib/supabase/server'?{createClient:async()=>client}:name==='@/lib/discovery/catalog-query'?queryModule.exports:name==='next/navigation'?{redirect(url){throw {redirect:url}}}:name==='@/components/discovery/site-header'?{SiteHeader:()=>null}:name==='@/components/discovery/live-catalog'?{LiveCatalog:()=>null}:require(name);
  new Function('require','exports','module',source)(mockRequire,module.exports,module);
  let redirect;try{await module.exports.default({searchParams:Promise.resolve(params)})}catch(e){if(!e.redirect)throw e;redirect=e.redirect}
  return {calls,redirect};
}
(async()=>{
  const empty=await run({page:'999',q:'Kingston',intent:'rent'},0);
  assert.equal(empty.redirect,'/listings?q=Kingston&intent=rent');
  assert(!empty.calls.some(x=>x[0]==='range'));
  const many=await run({page:'2',q:'Villa',intent:'sale',area:'Kingston'},130);
  assert.deepEqual(many.calls.find(x=>x[0]==='range'),['range',24,47]);
  assert.equal(many.calls.filter(x=>x[0]==='eq'&&x[1]==='status'&&x[2]==='published').length,2);
  assert.equal(many.calls.filter(x=>x[0]==='ilike'&&x[1]==='area'&&x[2]==='%Kingston%').length,2);
  assert.equal(many.calls.filter(x=>x[0]==='or'&&x[1]==='title.ilike.%Villa%,area.ilike.%Villa%').length,2);
  const unavailable=await run({page:'999'},null,{message:'offline'});
  assert(!unavailable.redirect);
  assert(!unavailable.calls.some(x=>x[0]==='range'));
  console.log('PASS: empty/out-of-range canonicalization before row fetching, full-inventory filters, published-only page queries and unavailable count handling');
})().catch(e=>{console.error(e);process.exitCode=1});
