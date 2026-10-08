const fs=require('fs'),vm=require('vm'),ts=require('typescript'),assert=require('node:assert/strict');
const mod={exports:{}};
new Function('exports','module',ts.transpileModule(fs.readFileSync('app/manifest.ts','utf8'),{compilerOptions:{module:ts.ModuleKind.CommonJS}}).outputText)(mod.exports,mod);
const manifest=mod.exports.default();assert.equal(manifest.display,'standalone');assert.equal(manifest.start_url,'/');assert.equal(manifest.scope,'/');
const icon=fs.readFileSync('public'+manifest.icons[0].src);assert.equal(icon.readUInt32BE(16),1254);assert.equal(icon.readUInt32BE(20),1254);
const listeners={},adds=[],deletes=[];let networkError=false,cacheMissing=false,claims=0;
const cache={add:async path=>adds.push(path),match:async path=>cacheMissing?undefined:new Response('offline screen')};
vm.runInNewContext(fs.readFileSync('public/sw.js','utf8'),{self:{location:{origin:'https://openhouse.test'},clients:{claim:async()=>claims++},addEventListener:(name,handler)=>listeners[name]=handler},caches:{open:async()=>cache,keys:async()=>['openhouse-offline-v0','openhouse-offline-v1','unrelated-cache'],delete:async key=>deletes.push(key)},URL,Response,fetch:async()=>{if(networkError)throw Error('offline');return new Response('private live response')}});
async function lifecycle(name){let pending;listeners[name]({waitUntil:p=>pending=p});await pending;}
async function request(overrides={}){let response;listeners.fetch({request:{method:'GET',mode:'navigate',url:'https://openhouse.test/account',...overrides},respondWith:p=>response=p});return response?await response:null;}
(async()=>{
 await lifecycle('install');assert.deepEqual(adds,['/offline.html']);await lifecycle('activate');assert.deepEqual(deletes,['openhouse-offline-v0']);assert.equal(claims,1);
 assert.equal(await (await request()).text(),'private live response');assert.deepEqual(adds,['/offline.html']);
 networkError=true;assert.equal(await (await request()).text(),'offline screen');
 for(const overrides of [{method:'POST'},{mode:'cors'},{url:'https://other.test/account'}])assert.equal(await request(overrides),null);
 cacheMissing=true;assert.equal((await request()).status,503);
 console.log('PASS: standalone branded manifest, actual icon dimensions, static-only offline caching, live private navigation, offline fallback, mutation/API/cross-origin bypass and scoped cache cleanup');
})().catch(error=>{console.error(error);process.exitCode=1});
