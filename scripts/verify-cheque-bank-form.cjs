const fs=require('fs'),ts=require('typescript'),assert=require('node:assert/strict'),React=require('react'),{renderToStaticMarkup}=require('react-dom/server');
const id='44556600-0000-4000-8000-000000000001',evidence='44556600-0000-4000-8000-000000000002';
function load(react=React,extra={}){const cache={};function read(path){if(cache[path])return cache[path];const m={exports:{}},req=name=>name==='react'?react:name==='next/navigation'?{useRouter:()=>({refresh(){extra.refreshes=(extra.refreshes||0)+1}})}:name.startsWith('@/lib/')?read(name.slice(2)+'.ts'):require(name);new Function('require','exports','module',ts.transpileModule(fs.readFileSync(path,'utf8'),{compilerOptions:{module:ts.ModuleKind.CommonJS,jsx:ts.JsxEmit.ReactJSX,target:ts.ScriptTarget.ES2022}}).outputText)(req,m.exports,m);return cache[path]=m.exports;}return read('components/finance/cheque-bank-form.tsx').ChequeBankForm;}
const props={chequeId:id,version:1,state:'received',files:[{id:evidence,kind:'deposit',file_name:'Deposit.pdf'},{id,kind:'clearance',file_name:'Clearance.pdf'}]},Component=load();
let html=renderToStaticMarkup(React.createElement(Component,props));assert.match(html,/Record bank deposit/);assert.doesNotMatch(html,/Clearance.pdf|Record bank clearance|Record bank return/);assert.match(html,/Deposit.pdf/);assert.doesNotMatch(html,/<input\b(?=[^>]*name="approved")(?=[^>]*checked)[^>]*>/);
html=renderToStaticMarkup(React.createElement(Component,{...props,state:'deposited'}));assert.match(html,/Record bank clearance|Record bank return/);assert.doesNotMatch(html,/Deposit.pdf/);
html=renderToStaticMarkup(React.createElement(Component,{...props,files:[]}));assert.match(html,/Upload and verify deposit evidence/);assert.match(html,/<button[^>]*disabled/);
for(const state of ['cancelled','returned'])assert.equal(renderToStaticMarkup(React.createElement(Component,{...props,state})), '');
let index=0,refIndex=0;const states=[],refs=[],extra={};const fake={...React,useState:initial=>{const n=index++;if(!(n in states))states[n]=initial;return [states[n],value=>states[n]=value]},useRef:initial=>{const n=refIndex++;if(!(n in refs))refs[n]={current:initial};return refs[n]}};
const Interactive=load(fake,extra);function find(node,test){if(!node||typeof node!=='object')return null;if(test(node))return node;for(const child of React.Children.toArray(node.props?.children)){const result=find(child,test);if(result)return result}return null;}
function tree(){index=0;refIndex=0;return Interactive(props)}
const originalFetch=global.fetch,OriginalFormData=global.FormData;let calls=[],status=503,resets=0;
const values={evidence_id:evidence,bank_reference:'BANK-101',reason:'Approved bank deposit',approved:'on'};
global.FormData=class{get(name){return values[name]}};
global.fetch=async(url,options)=>{assert.equal(url,'/api/staff/cheques');calls.push(JSON.parse(options.body));return new Response(JSON.stringify(status===200?{state:'deposited'}:{error:'Retry the same request'}),{status})};
async function submit(){await find(tree(),node=>node.type==='form').props.onSubmit({preventDefault(){},currentTarget:{reset(){resets++}}})}
(async()=>{try{
 await submit();await submit();assert.equal(calls.length,2);assert.equal(calls[0].request_id,calls[1].request_id);assert.equal(calls[0].evidence_id,evidence);assert.equal(calls[0].action,'record_deposit');assert.equal(resets,0);
 values.bank_reference='BANK-102';await submit();assert.notEqual(calls[1].request_id,calls[2].request_id);
 values.evidence_id=id;const before=calls.length;await submit();assert.equal(calls.length,before);assert.match(states[2],/current certified bank document/);
 values.evidence_id=evidence;values.approved='';await submit();assert.equal(calls.length,before);
 values.approved='on';status=200;await submit();assert.equal(resets,1);assert.equal(extra.refreshes,1);
 let release;global.fetch=async(_url,options)=>{calls.push(JSON.parse(options.body));await new Promise(resolve=>release=resolve);return new Response('{}',{status:200})};
 const first=submit(),count=calls.length;await submit();assert.equal(calls.length,count);release();await first;
 console.log('PASS: cheque bank form stage/evidence gates, unchecked approval, stable uncertain retries, changed-payload nonce, success reset and duplicate-submit lock');
 }finally{global.fetch=originalFetch;global.FormData=OriginalFormData}})().catch(error=>{console.error(error);process.exitCode=1});
