const fs=require('fs'),ts=require('typescript'),assert=require('node:assert/strict'),React=require('react');
const states=[],refs=[];let si=0,ri=0,calls=[],release,response,httpStatus=200,refreshes=0,reference='Approved sharing reference';
const fake={...React,useState:init=>{const n=si++;if(!(n in states))states[n]=init;return [states[n],v=>states[n]=v]},useRef:init=>{const n=ri++;return refs[n]||(refs[n]={current:init})}};
const moduleValue={exports:{}};
new Function('require','exports','module',ts.transpileModule(fs.readFileSync('components/leases/summary-release.tsx','utf8'),{compilerOptions:{module:ts.ModuleKind.CommonJS,jsx:ts.JsxEmit.ReactJSX,target:ts.ScriptTarget.ES2022}}).outputText)(n=>n==='react'?fake:n==='next/navigation'?{useRouter:()=>({refresh(){refreshes++}})}:n==='@/lib/enquiries/validation'?{uuidPattern:/^[a-f0-9-]{36}$/}:require(n),moduleValue.exports,moduleValue);
const id='66117788-0000-4000-8000-000000000001';
function tree(){si=0;ri=0;return moduleValue.exports.LeaseSummaryRelease({applicationId:id,draftId:id,version:2})}
function nodes(n,type,out=[]){if(Array.isArray(n)){n.forEach(v=>nodes(v,type,out));return out}if(!n||typeof n!=='object')return out;if(n.type===type)out.push(n);nodes(n.props?.children,type,out);return out}
const oldFetch=global.fetch,oldData=global.FormData;global.FormData=class{get(k){return k==='approved'?'on':reference}};
global.fetch=async(url,options)=>{assert.equal(url,'/api/staff/lease-summaries');calls.push(JSON.parse(options.body));await new Promise(resolve=>release=resolve);if(response instanceof Error)throw response;return new Response(JSON.stringify(response),{status:httpStatus})};
const event={preventDefault(){},currentTarget:{}};
(async()=>{try{
 const captured=nodes(tree(),'form')[0].props.onSubmit;const first=captured(event);await captured(event);assert.equal(calls.length,1);assert(nodes(tree(),'fieldset')[0].props.disabled);assert(nodes(tree(),'button')[0].props.disabled);
 response={id:'bad',draft_id:id,version:2,state:'released'};release();await first;assert.equal(states[1],true);assert(nodes(tree(),'fieldset')[0].props.disabled);assert(!nodes(tree(),'button')[0].props.disabled);
 reference='Changed approval reference';const denied=nodes(tree(),'form')[0].props.onSubmit(event);assert.deepEqual(calls.at(-1),calls[0]);httpStatus=403;response={error:'private authorization detail'};release();await denied;assert.equal(states[1],true);assert.equal(refs[2].current.request_id,calls[0].request_id);assert.doesNotMatch(states[2],/private/);
 const retry=nodes(tree(),'form')[0].props.onSubmit(event);assert.deepEqual(calls.at(-1),calls[0]);httpStatus=200;response={id,draft_id:id,version:2,state:'released'};release();await retry;assert.equal(refs[1].current,true);assert.match(states[2],/is recorded/);assert.match(states[2],/still current/);await captured(event);assert.equal(calls.length,3);
 states.length=0;refs.length=0;const corrected=nodes(tree(),'form')[0].props.onSubmit(event);const previous=calls.at(-1).request_id;httpStatus=400;response={error:'private validation'};release();await corrected;assert.equal(refs[2].current,null);assert.equal(nodes(tree(),'fieldset')[0].props.disabled,false);
 const interrupted=nodes(tree(),'form')[0].props.onSubmit(event);assert.notEqual(calls.at(-1).request_id,previous);response=new Error('private network');release();await interrupted;assert.equal(states[1],true);assert(nodes(tree(),'fieldset')[0].props.disabled);
 assert(refreshes>=1);console.log('PASS: lease release synchronous duplicate/completion guards, in-flight locks, malformed-success uncertainty, frozen/rejected retries, correction and network recovery');
 }finally{global.fetch=oldFetch;global.FormData=oldData}
})().catch(error=>{console.error(error);process.exitCode=1});
