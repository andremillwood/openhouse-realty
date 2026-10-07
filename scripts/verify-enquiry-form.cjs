const fs=require('fs'),ts=require('typescript'),assert=require('node:assert/strict'),React=require('react');
const states=[],refs=[];let si=0,ri=0,calls=[],release,response;
const fake={...React,useState:init=>{const n=si++;if(!(n in states))states[n]=init;return [states[n],v=>states[n]=v]},useRef:init=>{const n=ri++;return refs[n]||(refs[n]={current:init})}};
const moduleObject={exports:{}};
new Function('require','exports','module',ts.transpileModule(fs.readFileSync('components/enquiries/enquiry-form.tsx','utf8'),{compilerOptions:{module:ts.ModuleKind.CommonJS,jsx:ts.JsxEmit.ReactJSX,target:ts.ScriptTarget.ES2022}}).outputText)(n=>n==='react'?fake:require(n),moduleObject.exports,moduleObject);
const target='55667788-0000-4000-8000-000000000001';
function tree(){si=0;ri=0;return moduleObject.exports.EnquiryForm({realtorId:target})}
function nodes(node,predicate,out=[]){if(Array.isArray(node)){node.forEach(n=>nodes(n,predicate,out));return out}if(!node||typeof node!=='object')return out;if(predicate(node))out.push(node);nodes(node.props?.children,predicate,out);return out}
function form(){return nodes(tree(),n=>n.type==='form')[0]}
const oldFetch=global.fetch,oldFormData=global.FormData;let fields={contact_name:'Client Name',phone:'',message:'Please introduce me to this realtor.',consent:'on'};
global.FormData=class{get(key){return fields[key]??null}};
global.fetch=async(url,options)=>{assert.equal(url,'/api/enquiries');calls.push(JSON.parse(options.body));await new Promise(resolve=>release=resolve);if(response instanceof Error)throw response;return response};
const event={preventDefault(){},currentTarget:{}};
(async()=>{try{
 const captured=form().props.onSubmit;const first=captured(event);await captured(event);assert.equal(calls.length,1);assert.equal(calls[0].realtor_id,target);assert.equal(calls[0].listing_id,null);assert(nodes(tree(),n=>n.type==='fieldset')[0].props.disabled);
 response=new Error('Network lost');release();await first;assert.equal(states[1],false);assert.equal(states[4],true);assert(nodes(tree(),n=>n.type==='fieldset')[0].props.disabled);assert.match(states[2],/could not confirm/);
 fields.message='Edited details must not replace uncertain request.';const retry=form().props.onSubmit(event);assert.deepEqual(calls[1],calls[0]);response=new Response(JSON.stringify({message:'Looks successful'}),{status:201});release();await retry;assert.equal(states[1],false);assert.equal(states[4],true);
 const denied=form().props.onSubmit(event);response=new Response(JSON.stringify({error:'Sign in first'}),{status:401});release();await denied;assert.equal(states[3],true);assert.equal(states[4],true);assert.equal(refs[0].current.request_id,calls[0].request_id);assert.equal(nodes(tree(),n=>n.type==='fieldset')[0].props.disabled,true);
 // A new mount with a definite rejection can safely unlock corrected input.
 states.length=0;refs.length=0;const fresh=form().props.onSubmit(event);response=new Response(JSON.stringify({error:'Check your details'}),{status:400});release();await fresh;assert.equal(states[4],false);assert.equal(refs[0].current,null);assert.equal(nodes(tree(),n=>n.type==='fieldset')[0].props.disabled,false);
 const savedHandler=form().props.onSubmit;const saved=savedHandler(event);assert.notEqual(calls[4].request_id,calls[0].request_id);assert.equal(calls[4].message,fields.message);response=new Response(JSON.stringify({id:target,message:'Untrusted provider wording'}),{status:201});release();await saved;assert.equal(states[1],true);assert.match(states[2],/enquiry is stored/);await savedHandler(event);assert.equal(calls.length,5);
 console.log('PASS: enquiry duplicate protection, frozen uncertain retries, malformed success denial, sign-in recovery, corrected request IDs and confirmed completion guard');
}finally{global.fetch=oldFetch;global.FormData=oldFormData}})().catch(error=>{console.error(error);process.exitCode=1});
