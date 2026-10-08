const fs=require('fs'),ts=require('typescript'),React=require('react'),assert=require('node:assert/strict');
const states=[],refs=[],listeners={},removed=[];let si=0,ri=0,effect,cleanup,calls=0,resolveChoice;
const react={...React,useState:init=>{const i=si++;if(!(i in states))states[i]=init;return [states[i],value=>states[i]=value]},useRef:init=>{const i=ri++;return refs[i]||(refs[i]={current:init})},useEffect:fn=>effect=fn};
const m={exports:{}};new Function('require','exports','module',ts.transpileModule(fs.readFileSync('components/pwa/install-app.tsx','utf8'),{compilerOptions:{module:ts.ModuleKind.CommonJS,jsx:ts.JsxEmit.ReactJSX}}).outputText)(n=>n==='react'?react:require(n),m.exports,m);
const oldWindow=global.window;global.window={matchMedia:()=>({matches:false,addEventListener(){},removeEventListener(){}}),addEventListener:(name,fn)=>listeners[name]=fn,removeEventListener:(name,fn)=>{assert.equal(fn,listeners[name]);removed.push(name)}};
function tree(){si=0;ri=0;return m.exports.InstallApp();}function nodes(n,type,out=[]){if(Array.isArray(n)){n.forEach(x=>nodes(x,type,out));return out;}if(!n||typeof n!=='object')return out;if(n.type===type)out.push(n);nodes(n.props?.children,type,out);return out;}
(async()=>{try{
 tree();cleanup=effect();assert.equal(nodes(tree(),'button').length,0);
 let prevented=false;listeners.beforeinstallprompt({preventDefault(){prevented=true},prompt:async()=>calls++,userChoice:new Promise(resolve=>resolveChoice=resolve)});assert(prevented);
 const handler=nodes(tree(),'button')[0].props.onClick,first=handler();await handler();assert.equal(calls,1);assert(nodes(tree(),'button')[0].props.disabled);
 resolveChoice({outcome:'dismissed'});await first;assert.equal(nodes(tree(),'button').length,0);assert.match(states[3],/install later/);
 listeners.beforeinstallprompt({preventDefault(){},prompt:async()=>{throw Error('unsupported')},userChoice:Promise.resolve({outcome:'accepted'})});await nodes(tree(),'button')[0].props.onClick();assert.match(states[3],/browser menu/);
 listeners.appinstalled();assert.equal(states[1],true);cleanup();assert.deepEqual(removed.sort(),['appinstalled','beforeinstallprompt']);
 console.log('PASS: actual installation UI browser event capture, duplicate-click exclusion, pending lock, dismissed/error recovery, installed state and event cleanup');
}finally{global.window=oldWindow}})().catch(error=>{console.error(error);process.exitCode=1});
