const fs=require('fs'),ts=require('typescript'),assert=require('node:assert/strict'),React=require('react'),{renderToStaticMarkup}=require('react-dom/server'),id='55667788-0000-4000-8000-000000000001';
async function run(path,input,{user={id},membership={organization_id:'own'},count=62,countError=null,record={id,user_id:id,company_name:'Approved Contractor',trade_coverage:['Plumbing'],is_active:true,version:1},target=id}={}){
 const calls=[],editors=[];const client={from(table){let head=false;const b={select(fields,options){head=options?.head;calls.push([table,'select',head]);return b},eq(...args){calls.push([table,'eq',...args]);return b},order(){return b},maybeSingle(){return Promise.resolve({data:record,error:null})},range(...args){calls.push([table,'range',...args]);return Promise.resolve({data:[],error:null})},then(resolve,reject){assert(head);return Promise.resolve({count,error:countError}).then(resolve,reject)}};return b;}};
 const m={exports:{}},req=name=>name==='@/lib/staff/access'?{catalogAccess:async roles=>{calls.push(['access',roles]);return {client,user,membership}}}:name==='next/navigation'?{redirect(url){throw {redirect:url}},notFound(){throw {notFound:true}}}:name==='@/components/discovery/site-header'?{SiteHeader:()=>null}:name==='@/components/staff/contractor-editor'?{ContractorEditor:props=>{editors.push(props);return React.createElement('div',null,props.action)}}:require(name);
 new Function('require','exports','module',ts.transpileModule(fs.readFileSync(path,'utf8'),{compilerOptions:{module:ts.ModuleKind.CommonJS,jsx:ts.JsxEmit.ReactJSX,target:ts.ScriptTarget.ES2022}}).outputText)(req,m.exports,m);let exception,html;try{html=renderToStaticMarkup(await m.exports.default({params:Promise.resolve({accessId:target}),searchParams:Promise.resolve(input)}));}catch(e){exception=e;}return {calls,editors,exception,html};
}
(async()=>{
 const detail='app/staff/owner-access/[accessId]/page.tsx';
 let r=await run(detail,{page:'3'});assert(!r.exception);assert.deepEqual(r.calls[0],['access',['admin']]);
 assert(r.calls.some(c=>c[0]==='owner_property_access'&&c[2]==='organization_id'&&c[3]==='own'));
 for(const [key,value] of [['organization_id','own'],['access_id',id]])assert.equal(r.calls.filter(c=>c[0]==='owner_property_access_changes'&&c[2]===key&&c[3]===value).length,2);
 assert.deepEqual(r.calls.find(c=>c[1]==='range'),['owner_property_access_changes','range',50,74]);
 r=await run(detail,{page:'999'},{count:0});assert.equal(r.exception.redirect,`/staff/owner-access/${id}?page=1`);assert(!r.calls.some(c=>c[1]==='range'));
 r=await run(detail,{},{record:null});assert(r.exception.notFound);assert(!r.calls.some(c=>c[0]==='owner_property_access_changes'));
 r=await run(detail,{},{target:'bad'});assert(r.exception.notFound);assert.equal(r.calls.length,1);
 for(const config of [{user:null},{membership:null}]){r=await run(detail,{},config);assert(r.exception);assert.equal(r.calls.length,1);}
 r=await run(detail,{},{countError:{message:'offline'}});assert(r.exception instanceof Error);assert(!r.calls.some(c=>c[1]==='range'));
 console.log('PASS: owner approval history administrator gate, parent/org binding, bounded pagination and denied/count failure paths');
})().catch(error=>{console.error(error);process.exitCode=1});
