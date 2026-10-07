const fs=require('fs'),ts=require('typescript'),assert=require('node:assert/strict'),React=require('react'),{renderToStaticMarkup}=require('react-dom/server');
function compile(path){return ts.transpileModule(fs.readFileSync(path,'utf8'),{compilerOptions:{module:ts.ModuleKind.CommonJS,jsx:ts.JsxEmit.ReactJSX,target:ts.ScriptTarget.ES2022}}).outputText}
const vm={exports:{}};new Function('exports','module',compile('lib/owners/access-validation.ts'))(vm.exports,vm);
function load(hooks){const m={exports:{}};new Function('require','exports','module',compile('components/staff/owner-access-editor.tsx'))(name=>name==='react'&&hooks?hooks:name==='@/lib/owners/access-validation'?vm.exports:require(name),m.exports,m);return m.exports.OwnerAccessEditor}
const id='44556600-0000-4000-8000-000000000020',props={propertyId:id};
const html=renderToStaticMarkup(React.createElement(load(),props));assert.match(html,/name="email"/);assert.match(html,/<input\b(?=[^>]*name="approved")(?=[^>]*required)[^>]*>/);assert.doesNotMatch(html,/<input\b(?=[^>]*name="approved")(?=[^>]*checked)[^>]*>/);
(async()=>{const original={fetch:global.fetch,FormData:global.FormData,window:global.window};let mode='network',reloads=0;const requests=[],messages=[],retry={current:null};try{
global.FormData=class{constructor(form){this.form=form}get(name){return this.form[name]}};global.window={location:{reload(){reloads++}}};global.fetch=async(url,options)=>{requests.push({url,body:JSON.parse(options.body)});if(mode==='network')throw Error('Connection lost');return {ok:mode==='success',status:mode==='conflict'?409:mode==='server'?503:200,json:async()=>({id,error:'Refresh changed access'})}};
const Editor=load({...React,useState:()=>[false,value=>messages.push(value)],useRef:()=>retry});const form={email:'Approved@example.invalid',reason:'Approved portfolio access',approved:'on'},event={preventDefault(){},currentTarget:form},submit=Editor(props).props.onSubmit;
form.approved=null;await submit(event);assert.equal(requests.length,0);form.approved='on';
await submit(event);await submit(event);assert.equal(requests[0].body.request_id,requests[1].body.request_id);assert.equal(requests[0].url,'/api/staff/owner-access');assert.equal(requests[0].body.property_id,id);assert.equal(requests[0].body.access_id,null);
mode='server';await submit(event);assert.equal(requests[2].body.request_id,requests[0].body.request_id);
mode='conflict';await submit(event);assert.equal(retry.current,null);assert(messages.includes('Refresh changed access'));
mode='success';await submit(event);assert.notEqual(requests[4].body.request_id,requests[0].body.request_id);assert.equal(reloads,1);
form.reason='Different approved access';await submit(event);assert.notEqual(requests[5].body.request_id,requests[4].body.request_id);
const change=Editor({...props,access:{id,user_id:id,is_active:true,version:2}}).props.onSubmit;form.is_active=null;await change(event);const last=requests.at(-1).body;assert.equal(last.version,2);assert.equal(last.access_id,id);assert.equal(last.email,null);assert.equal(last.property_id,null);assert.equal(last.is_active,false);
console.log('PASS: owner access explicit approval, grant/revocation payloads, network/server retry identity, conflict feedback and successful refresh');
}finally{Object.assign(global,original)}})().catch(e=>{console.error(e);process.exitCode=1});
