const fs=require('fs'),ts=require('typescript'),assert=require('node:assert/strict'),React=require('react'),{renderToStaticMarkup}=require('react-dom/server');
const id='44556600-0000-4000-8000-000000000001',credit='44556600-0000-4000-8000-000000000002',props={invoiceId:id,version:3,amount:'JMD 100.01'};
function AccountPicker(){return null}
const extra={pushes:[],refreshes:0};
function load(react=React){const cache={};function read(path){if(cache[path])return cache[path];const m={exports:{}},req=name=>name==='react'?react:name==='next/navigation'?{useRouter:()=>({push:url=>extra.pushes.push(url),refresh:()=>extra.refreshes++})}:name==='@/components/finance/account-picker'?{AccountPicker}:name.startsWith('@/lib/')?read(name.slice(2)+'.ts'):require(name);new Function('require','exports','module',ts.transpileModule(fs.readFileSync(path,'utf8'),{compilerOptions:{module:ts.ModuleKind.CommonJS,jsx:ts.JsxEmit.ReactJSX,target:ts.ScriptTarget.ES2022}}).outputText)(req,m.exports,m);return cache[path]=m.exports;}return read('components/finance/invoice-posting-form.tsx').InvoicePostingForm;}
const html=renderToStaticMarkup(React.createElement(load(),props));assert.match(html,/JMD 100.01/);assert.match(html,/<button[^>]*disabled/);assert.doesNotMatch(html,/<input\b(?=[^>]*name="approved")(?=[^>]*checked)[^>]*>/);
let index=0,refIndex=0;const states=[],refs=[],fake={...React,useState:initial=>{const n=index++;if(!(n in states))states[n]=initial;return [states[n],value=>states[n]=value]},useRef:initial=>{const n=refIndex++;if(!(n in refs))refs[n]={current:initial};return refs[n]}};
const Component=load(fake);function tree(){index=0;refIndex=0;return Component(props)}
function all(node,test,result=[]){if(!node||typeof node!=='object')return result;if(test(node))result.push(node);for(const child of React.Children.toArray(node.props?.children))all(child,test,result);return result}
function accounts(debitValue,creditValue){const pickers=all(tree(),node=>node.type===AccountPicker);pickers[0].props.onChange(debitValue);pickers[1].props.onChange(creditValue)}
const savedFetch=global.fetch,SavedFormData=global.FormData,values={reason:'Approved invoice accounting',approved:'on'};let calls=[],status=503;
global.FormData=class{get(name){return values[name]}};
global.fetch=async(url,options)=>{assert.equal(url,'/api/staff/invoice-postings');calls.push(JSON.parse(options.body));return new Response(JSON.stringify(status===200?{journal_id:id}:{error:'Retry the same request'}),{status})};
async function submit(){await all(tree(),node=>node.type==='form')[0].props.onSubmit({preventDefault(){},currentTarget:{}})}
(async()=>{try{
 const initialPickers=all(tree(),node=>node.type===AccountPicker);assert.deepEqual(initialPickers[0].props.accountClasses,['expense', 'asset']);assert.deepEqual(initialPickers[1].props.accountClasses,['liability']);
 await submit();assert.equal(calls.length,0);accounts(id,id);await submit();assert.equal(calls.length,0);
 accounts(id,credit);values.approved='';await submit();assert.equal(calls.length,0);values.approved='on';
 await submit();await submit();assert.equal(calls.length,2);assert.equal(calls[0].request_id,calls[1].request_id);assert(!('amount_minor' in calls[0]));assert.equal(extra.pushes.length,0);
 values.reason='Changed approved accounting reason';await submit();assert.notEqual(calls[1].request_id,calls[2].request_id);
 status=409;await submit();const prior=calls.at(-1).request_id;status=503;await submit();assert.notEqual(calls.at(-1).request_id,prior);
 status=200;await submit();assert.deepEqual(extra.pushes,[`/staff/finance/journals/${id}`]);assert.equal(extra.refreshes,1);
 let release;global.fetch=async(_url,options)=>{calls.push(JSON.parse(options.body));await new Promise(resolve=>release=resolve);return new Response(JSON.stringify({journal_id:id}),{status:200})};const first=submit(),count=calls.length;await submit();assert.equal(calls.length,count);release();await first;
 console.log('PASS: invoice posting form account/approval gates, server-derived amount, stable uncertain retries, changed/conflict nonce, success navigation and duplicate-submit lock');
 }finally{global.fetch=savedFetch;global.FormData=SavedFormData}})().catch(error=>{console.error(error);process.exitCode=1});
