const fs=require('fs'),ts=require('typescript'),assert=require('node:assert/strict');
const source=ts.transpileModule(fs.readFileSync('components/auth/save-property.tsx','utf8'),{compilerOptions:{module:ts.ModuleKind.CommonJS,jsx:ts.JsxEmit.ReactJSX,target:ts.ScriptTarget.ES2022}}).outputText;
async function run({anonymous=false,verified=true,failure=false,refresh=true,initialSaved=true}={}){
 let finish,refreshes=0,authCalls=0,writes=0;const scopes=[],messages=[],redirects=[];
 const pending=new Promise(resolve=>finish=resolve);
 const client={auth:{getUser:async()=>{authCalls++;return {data:{user:{id:'owner',email_confirmed_at:verified?'verified':null,is_anonymous:anonymous}},error:null}}},from(table){assert.equal(table,'saved_listings');const q={delete(){writes++;return q},eq(...args){scopes.push(args);return q},upsert(record,options){writes++;scopes.push(record);assert.equal(options.ignoreDuplicates,true);return q},then(resolve,reject){return pending.then(resolve,reject)}};return q}};
 const m={exports:{}};new Function('require','exports','module',source)(name=>name==='react'?{useRef:value=>({current:value}),useState:value=>[value,next=>messages.push(next)]}:name==='next/navigation'?{useRouter:()=>({refresh(){refreshes++}})}:name==='@/lib/supabase/client'?{createClient:()=>client}:name==='@/lib/auth-return'?{propertySignInHref:id=>'/sign-in?property='+id}:require(name),m.exports,m);
 global.window={location:{assign:value=>redirects.push(value)}};
 try{
  const tree=m.exports.SaveProperty({listingId:'listing',initialSaved,refreshAfterChange:refresh});
  const button=tree.props.children[0];const first=button.props.onClick();const duplicate=button.props.onClick();await new Promise(resolve=>setImmediate(resolve));
  assert.equal(authCalls,1);
  if(anonymous||!verified){await Promise.all([first,duplicate]);assert.equal(writes,0);assert.equal(refreshes,0);assert.equal(redirects.length,1);return;}
  assert.equal(writes,1);finish({error:failure?{message:'offline'}:null});await Promise.all([first,duplicate]);
  assert.equal(refreshes,!failure&&refresh?1:0);
  if(initialSaved)assert.deepEqual(scopes,[['user_id','owner'],['listing_id','listing']]);else assert.deepEqual(scopes,[{user_id:'owner',listing_id:'listing'}]);
  assert(messages.includes(failure?'Unable to update saved properties. Please retry.':initialSaved?'Removed from your saved properties.':'Saved to your account.'));
 }finally{delete global.window;}
}
(async()=>{for(const config of [{},{refresh:false},{failure:true},{initialSaved:false},{anonymous:true},{verified:false}])await run(config);console.log('PASS: actual saved-property control synchronous duplicate lock, verified owner writes, anonymous denial, success-only optional route refresh and mutation failure feedback');})().catch(error=>{console.error(error);process.exitCode=1});
