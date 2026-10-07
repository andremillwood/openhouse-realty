const fs=require('fs'),ts=require('typescript'),assert=require('node:assert/strict'),{renderToStaticMarkup}=require('react-dom/server');
const id='66117788-0000-4000-8000-000000000001';
const item={id,version:1,state:'prepared',starts_on:'2026-10-08',ends_on:'2027-10-08',billing_day:31,rent_minor:'10000010',deposit_minor:'0',property_name:'Managed home',unit_label:'Unit A',template_title:'Residential template',released_at:'2026-10-07T13:00:00Z'};
async function run({user={id:'actual-applicant',email_confirmed_at:'confirmed'},application=true,data={total:1,items:[item]},rpcError=null,rpcThrow=false,page='1'}={}){
 const calls=[];const client={auth:{getUser:async()=>({data:{user},error:null})},from(table){assert.equal(table,'rental_applications');const b={select(fields){assert.equal(fields,'id,title_snapshot');return b},eq(k,v){calls.push([k,v]);return b},maybeSingle:async()=>({data:application?{id,title_snapshot:'Rental fixture'}:null,error:null})};return b},rpc:async(name,args)=>{calls.push([name,args]);if(rpcThrow)throw Error('private backend');return {data,error:rpcError}}};const cache={};
 function load(path){if(cache[path])return cache[path];const m={exports:{}};new Function('require','exports','module',ts.transpileModule(fs.readFileSync(path,'utf8'),{compilerOptions:{module:ts.ModuleKind.CommonJS,jsx:ts.JsxEmit.ReactJSX,target:ts.ScriptTarget.ES2022}}).outputText)(name=>name==='@/lib/supabase/server'?{createClient:async()=>client}:name==='next/navigation'?{redirect(url){throw {redirect:url}},notFound(){throw {notFound:true}}}:name==='@/components/discovery/site-header'?{SiteHeader:()=>null}:name.startsWith('@/lib/')?load(name.slice(2)+'.ts'):require(name),m.exports,m);return cache[path]=m.exports;}
 try{return {html:renderToStaticMarkup(await load('app/applications/[id]/lease/page.tsx').default({params:Promise.resolve({id}),searchParams:Promise.resolve({page})})),calls};}catch(error){return {error,calls};}
}
(async()=>{
 let r=await run({user:null});assert.equal(r.error.redirect,'/sign-in');assert.equal(r.calls.length,0);r=await run({user:{id:'actual-applicant'}});assert.equal(r.error.redirect,'/sign-in');
 r=await run({application:false});assert(r.error.notFound);assert(!r.calls.some(c=>c[0]==='applicant_lease_summaries'));
 r=await run();assert(r.calls.some(c=>c[0]==='user_id'&&c[1]==='actual-applicant'));assert.deepEqual(r.calls.at(-1),['applicant_lease_summaries',{p_application_id:id,p_page:1}]);assert.match(r.html,/100,000.10/);assert.match(r.html,/permission to move in/);assert.match(r.html,/receipt not established/);
 r=await run({data:{total:0,items:[]}});assert.match(r.html,/has not shared/);assert.doesNotMatch(r.html,/Prepared summary/);
 for(const options of [{rpcError:{message:'private backend'}},{rpcThrow:true},{data:{total:1,items:[{...item,state:'signed'}]}}]){r=await run(options);assert.match(r.html,/Unable to load/);assert.doesNotMatch(r.html,/has not shared|private backend/);}
 r=await run({page:'99',data:{total:51,items:[]}});assert.equal(r.error.redirect,`/applications/${id}/lease?page=3`);
 r=await run({page:'2',data:{total:51,items:[{...item,state:'voided'}]}});assert.match(r.html,/Withdrawn summary/);assert.match(r.html,/no longer current/);assert.match(r.html,/page=1/);assert.match(r.html,/page=3/);
 console.log('PASS: verified applicant ownership, bounded shared-history RPC, exact money, empty/error distinction, historical warnings and pagination');
})().catch(error=>{console.error(error);process.exitCode=1});
