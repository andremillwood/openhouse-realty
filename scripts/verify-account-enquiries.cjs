const fs=require('fs'),ts=require('typescript'),assert=require('node:assert/strict'),{renderToStaticMarkup}=require('react-dom/server');
const source=ts.transpileModule(fs.readFileSync('app/account/enquiries/page.tsx','utf8'),{compilerOptions:{module:ts.ModuleKind.CommonJS,jsx:ts.JsxEmit.ReactJSX,target:ts.ScriptTarget.ES2022}}).outputText;
async function run({verified=true,page='2',count=51,countError=false,rowError=false,rows=[{id:'own-enquiry',status:'new',message:'My private enquiry',created_at:'2026-10-07T12:00:00Z',listing_id:null,realtor_id:'realtor'}]}={}){
 const calls=[];const client={auth:{getUser:async()=>({data:{user:{id:'actual-account',email_confirmed_at:verified?'verified':null}},error:null})},from(table){assert.equal(table,'enquiries');let head=false;const b={select(value,options){head=!!options?.head;calls.push(['select',value,options]);return b},eq(...args){calls.push(['eq',...args]);return b},order(...args){calls.push(['order',...args]);return b},range(...args){calls.push(['range',...args]);return b},then(resolve){resolve(head?{count,error:countError?{}:null}:{data:rows,error:rowError?{}:null})}};return b}};
 const m={exports:{}};new Function('require','exports','module',source)(name=>name==='@/lib/supabase/server'?{createClient:async()=>client}:name==='next/navigation'?{redirect(url){throw {redirect:url}}}:name==='@/components/discovery/site-header'?{SiteHeader:()=>null}:require(name),m.exports,m);
 try{return {html:renderToStaticMarkup(await m.exports.default({searchParams:Promise.resolve({page})})),calls}}catch(error){return {error,calls}}
}
(async()=>{
 let result=await run({verified:false});assert.equal(result.error.redirect,'/sign-in');assert.equal(result.calls.length,0);
 result=await run();assert(!result.error);assert.deepEqual(result.calls.filter(c=>c[0]==='eq'),[['eq','user_id','actual-account'],['eq','user_id','actual-account']]);assert.deepEqual(result.calls.find(c=>c[0]==='range'),['range',25,49]);assert.deepEqual(result.calls.filter(c=>c[0]==='order'),[['order','created_at',{ascending:false}],['order','id']]);assert.match(result.html,/51 enquiries/);assert.match(result.html,/Page 2 of 3/);assert.match(result.html,/Realtor introduction/);assert.match(result.html,/My private enquiry/);assert.match(result.html,/own-enquiry/);assert.match(result.html,/does not confirm a viewing/);
 result=await run({page:'99'});assert.equal(result.error.redirect,'/account/enquiries?page=3');assert(!result.calls.some(c=>c[0]==='range'));
 result=await run({countError:true});assert(result.error);assert(!result.calls.some(c=>c[0]==='range'));
 result=await run({rowError:true});assert.match(result.html,/Unable to load your enquiries/);assert.doesNotMatch(result.html,/My private enquiry/);
 result=await run({count:0,rows:[],page:'1'});assert.match(result.html,/No stored enquiries/);assert.match(result.html,/Page 1 of 1/);
 console.log('PASS: verified enquiry history, owner-scoped count/rows, bounded stable pagination, out-of-range handling and truthful recovery/error states');
})().catch(error=>{console.error(error);process.exitCode=1});
