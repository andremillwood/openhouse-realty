const fs=require('fs'),ts=require('typescript'),assert=require('node:assert/strict'),React=require('react');
const states=[],refs=[];let si=0,ri=0,calls=[],release,response;
const fake={...React,useState:init=>{const n=si++;if(!(n in states))states[n]=init;return [states[n],v=>states[n]=typeof v==='function'?v(states[n]):v]},useRef:init=>{const n=ri++;return refs[n]||(refs[n]={current:init})}};
const moduleObject={exports:{}};
new Function('require','exports','module',ts.transpileModule(fs.readFileSync('components/viewings/viewing-list.tsx','utf8'),{compilerOptions:{module:ts.ModuleKind.CommonJS,jsx:ts.JsxEmit.ReactJSX,target:ts.ScriptTarget.ES2022}}).outputText)(n=>n==='react'?fake:n==='next/navigation'?{useRouter:()=>({refresh(){}})}:n==='@/lib/viewings/validation'?{viewingTime:x=>x}:require(n),moduleObject.exports,moduleObject);
const id='55667788-0000-4000-8000-000000000001';
const row={id,slot_id:id,listing_id:id,title_snapshot:'Viewing',requested_for:'2099-10-08T12:00:00Z',ends_at:'2099-10-08T13:00:00Z',hold_expires_at:'2099-10-08T10:00:00Z',status:'requested',cancellation_reason:null};
function tree(){si=0;ri=0;return moduleObject.exports.ViewingList({viewings:[row],staff:true})}
function nodes(n,type,out=[]){if(Array.isArray(n)){n.forEach(v=>nodes(v,type,out));return out}if(!n||typeof n!=='object')return out;if(n.type===type)out.push(n);nodes(n.props?.children,type,out);return out}
function button(label){return nodes(tree(),'button').find(n=>n.props.children===label)}
const old=global.fetch;let httpStatus=200;global.fetch=async(url,options)=>{calls.push(JSON.parse(options.body));await new Promise(resolve=>release=resolve);return new Response(JSON.stringify(response),{status:httpStatus})};
(async()=>{try{
 button('Cancel viewing').props.onClick();nodes(tree(),'textarea')[0].props.onChange({target:{value:'My plans changed'}});
 const captured=button('Confirm cancellation').props.onClick;const first=captured();await captured();assert.equal(calls.length,1);assert(nodes(tree(),'button').every(n=>n.props.disabled));assert(nodes(tree(),'textarea')[0].props.disabled);response={status:'confirmed'};release();await first;assert.equal(states[0][0].status,'requested');assert.equal(states[4],'My plans changed');assert.match(states[2],/could not be confirmed/);
 const valid=button('Confirm cancellation').props.onClick();response={status:'cancelled'};release();await valid;assert.equal(states[0][0].status,'cancelled');assert.equal(states[0][0].cancellation_reason,'My plans changed');assert.equal(states[3],'');
 states.length=0;refs.length=0;const expired=button('Confirm viewing').props.onClick();httpStatus=409;response={status:'expired',error:'Window expired'};release();await expired;assert.equal(states[0][0].status,'expired');assert.match(states[2],/window expired/);
 console.log('PASS: viewing transition duplicate guard, locked cancellation controls, malformed-status denial, retained reason, confirmed cancellation and committed expiry');
}finally{global.fetch=old}})().catch(e=>{console.error(e);process.exitCode=1});
