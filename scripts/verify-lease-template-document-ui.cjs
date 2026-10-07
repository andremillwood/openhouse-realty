const fs=require('fs'),ts=require('typescript'),assert=require('node:assert/strict'),React=require('react'),{renderToStaticMarkup}=require('react-dom/server');
function load(react=React,extra={}){const m={exports:{}};const req=name=>name==='react'?react:name==='next/navigation'?{useRouter:()=>({refresh(){extra.refreshes=(extra.refreshes||0)+1}})}:name==='@/lib/supabase/client'?{createClient:()=>({storage:{from:bucket=>({uploadToSignedUrl:async(path,token,file,options)=>{extra.uploads.push({bucket,path,token,file,options});return {error:extra.uploadError}}})}})}:name==='@/lib/documents/files'?{documentFile:(name,mime,size)=>{if(size>8388608)throw Error('Oversize fixture')}}:name==='@/lib/leases/template-documents'?{LEASE_TEMPLATE_BUCKET:'lease-template-documents'}:require(name);new Function('require','exports','module',ts.transpileModule(fs.readFileSync('components/leases/template-document-files.tsx','utf8'),{compilerOptions:{module:ts.ModuleKind.CommonJS,jsx:ts.JsxEmit.ReactJSX,target:ts.ScriptTarget.ES2022}}).outputText)(req,m.exports,m);return m.exports.TemplateDocumentFiles}
const file={id:'evidence',user_id:'uploader',kind:'deposit',file_name:'Bank.pdf',state:'certified',expires_at:'2099-01-01T00:00:00Z'},Component=load(),props={files:[file],templateId:'template',enabled:true,currentUserId:'uploader'};
const render=extra=>renderToStaticMarkup(React.createElement(Component,{...props,...extra}));
let html=render({});assert.match(html,/Download approved PDF/);assert.doesNotMatch(html,/Withdraw reservation|type="file"/);assert.match(html,/Certification does not sign/);
html=render({files:[]});assert.match(html,/type="file"/);assert.match(html,/application\/pdf/);
html=render({files:[],enabled:false});assert.match(html,/uploads are being configured/);assert.doesNotMatch(html,/type="file"/);
html=render({files:[{...file,state:'reserved'}]});assert.match(html,/Verify uploaded PDF|Withdraw reservation/);
html=render({files:[{...file,state:'reserved'}],currentUserId:'other-admin'});assert.doesNotMatch(html,/Verify uploaded PDF|Withdraw reservation/);
html=render({files:[{...file,state:'reserved',expires_at:'2000-01-01T00:00:00Z'}]});assert.doesNotMatch(html,/Verify uploaded PDF/);assert.match(html,/Reservation expired/);
console.log('PASS: approved PDF UI certification, ownership, configuration and expiry gates');

const state=[],refs=[],extra={uploads:[],refreshes:0};let index=0,refIndex=0;
const fakeReact={...React,useState:initial=>{const n=index++;if(!(n in state))state[n]=initial;return [state[n],value=>{state[n]=value}]},useRef:initial=>{const n=refIndex++;if(!(n in refs))refs[n]={current:initial};return refs[n]}};
const Interactive=load(fakeReact,extra);function tree(){index=0;refIndex=0;return Interactive({...props,files:[]})}function find(node,predicate){if(!node||typeof node!=='object')return null;if(predicate(node))return node;for(const child of React.Children.toArray(node.props?.children)){const found=find(child,predicate);if(found)return found}return null}
const selected={name:'bank.pdf',type:'application/pdf',size:100},elements={namedItem:name=>name==='file'?{files:[selected]}:{value:'deposit'}};let resets=0,calls=[],reserveFails=true,finishFails=false;
const original=global.fetch;global.fetch=async(_url,options)=>{const body=JSON.parse(options.body);calls.push(body);if(body.action==='reserve'&&reserveFails){reserveFails=false;throw Error('Network interrupted')}if(body.action==='finish'&&finishFails)return new Response(JSON.stringify({error:'Retry certification'}),{status:503});return new Response(JSON.stringify(body.action==='reserve'?{id:'evidence',path:'template/file.pdf',token:'token',state:'reserved'}:{state:'certified'}),{status:200})};
async function upload(){const form=find(tree(),n=>n.type==='form');await form.props.onSubmit({preventDefault(){},currentTarget:{elements,reset(){resets++}}})}
(async()=>{try{
 await upload();const requestId=calls[0].request_id;assert.equal(extra.uploads.length,0);
 finishFails=true;await upload();assert.equal(calls[1].request_id,requestId);assert.equal(extra.uploads.length,1);assert.deepEqual(extra.uploads[0].options,{contentType:'application/pdf'});assert.equal(resets,0);
 finishFails=false;const before=calls.length;await upload();assert.deepEqual(calls.slice(before),[{action:'finish',id:'evidence'}]);assert.equal(extra.uploads.length,1);assert.equal(resets,1);
 extra.uploadError={message:'ambiguous transfer response'};await upload();assert.equal(calls.at(-1).action,'finish');assert.equal(resets,2);
 let release;const fetchBefore=global.fetch;global.fetch=async(url,options)=>{await new Promise(resolve=>{release=resolve});return fetchBefore(url,options)};const concurrent=upload();await Promise.resolve();const beforeDuplicate=calls.length;await upload();assert.equal(calls.length,beforeDuplicate);global.fetch=fetchBefore;release();await concurrent;
 selected.size=8388609;const count=calls.length;await upload();assert.equal(calls.length,count);assert.match(state[1],/Oversize/);
 console.log('PASS: approved legal PDF UI read-only/configuration gates, same-file reservation retries, certification retry without overwrite and ambiguous transfer recovery');
 }finally{global.fetch=original}})().catch(error=>{console.error(error);process.exitCode=1});
