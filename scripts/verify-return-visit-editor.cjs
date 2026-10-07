const fs=require('fs'),ts=require('typescript'),assert=require('node:assert/strict'),React=require('react'),{renderToStaticMarkup}=require('react-dom/server');
const source=fs.readFileSync('components/staff/return-visit-editor.tsx','utf8');
function load(hooks){const module={exports:{}};new Function('require','exports','module',ts.transpileModule(source,{compilerOptions:{module:ts.ModuleKind.CommonJS,jsx:ts.JsxEmit.ReactJSX,target:ts.ScriptTarget.ES2022}}).outputText)(name=>name==='react'&&hooks?hooks:require(name),module.exports,module);return module.exports.ReturnVisitEditor;}
const props={reportId:'report',reportVersion:2,offerVersion:7,workVersion:8,returnTo:'/staff/work-orders/work/visits'};
const html=renderToStaticMarkup(React.createElement(load(),props));assert.match(html,/<input\b(?=[^>]*name="approved")(?=[^>]*required)[^>]*>/);assert.doesNotMatch(html,/<input\b(?=[^>]* checked=)[^>]*>/);assert.match(html,/documentation-only corrections/);assert.match(html,/name="reason"/);
(async()=>{const original={fetch:global.fetch,FormData:global.FormData,window:global.window};const requests=[],redirects=[],messages=[],retry={current:null};let mode='network';
try{
global.FormData=class{constructor(form){this.form=form}get(name){return this.form[name]}};global.window={location:{assign:path=>redirects.push(path)}};
global.fetch=async(url,options)=>{requests.push({url,body:JSON.parse(options.body)});if(mode==='network')throw Error('Connection lost');return {ok:mode==='success',status:mode==='conflict'?409:mode==='server'?503:200,json:async()=>({error:'Refresh changed work'})}};
const Editor=load({...React,useState:()=>[false,value=>messages.push(value)],useRef:()=>retry});
const form={reason:'Approved physical correction',approved:'on'},submit=Editor(props).props.onSubmit;
const event={preventDefault(){},currentTarget:form};
await submit(event);await submit(event);assert.equal(requests[0].body.request_id,requests[1].body.request_id);assert.equal(requests[0].url,'/api/contractor-return-visits');assert.deepEqual({...requests[0].body,request_id:undefined},{report_id:'report',report_version:2,offer_version:7,work_version:8,reason:form.reason,approved:true,request_id:undefined});assert.equal(redirects.length,0);
mode='server';await submit(event);assert.equal(requests[2].body.request_id,requests[0].body.request_id);
mode='conflict';await submit(event);assert.equal(retry.current,null);assert(messages.includes('Refresh changed work'));
mode='success';await submit(event);assert.notEqual(requests[4].body.request_id,requests[0].body.request_id);assert.deepEqual(redirects,[props.returnTo]);
form.reason='Different approved corrections';await submit(event);assert.notEqual(requests[5].body.request_id,requests[4].body.request_id);
form.approved=null;await submit(event);assert.equal(requests[6].body.approved,false);
console.log('PASS: return-visit form fresh approval, revision payload, network/server retry identity, conflict feedback and scheduling handoff');
}finally{Object.assign(global,original)}
})().catch(error=>{console.error(error);process.exitCode=1});
