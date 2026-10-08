/* Read-only public release smoke check. Does not prove visual or signed-in acceptance. */
const assert=require('node:assert/strict');
const base=new URL(process.argv[2]||'https://www.openhousejamaica.com');
assert(['https:','http:'].includes(base.protocol)&&!base.username&&!base.password,'Use a public HTTP(S) origin without credentials');
const origin=base.origin;
const pages=['/','/about','/services','/contact','/sell','/listings','/realtors','/open-houses','/install','/sign-in'];
async function read(path){const response=await fetch(new URL(path,origin),{signal:AbortSignal.timeout(20000),redirect:'follow'});assert.equal(response.status,200,`${path}: HTTP ${response.status}`);assert.equal(new URL(response.url).origin,origin,`${path}: unexpected cross-origin redirect`);return response.text();}
async function batches(items,run){for(let offset=0;offset<items.length;offset+=4)await Promise.all(items.slice(offset,offset+4).map(run));}
(async()=>{
 const links=new Set();
 await batches(pages,async path=>{
  const html=await read(path);
  for(const match of html.matchAll(/<a\b[^>]*\bhref="([^"]*)"/gi)){
   const url=new URL(match[1].replaceAll('&amp;','&'),new URL(path,origin));
   if(url.origin===origin&&!url.pathname.startsWith('/api/')&&!url.pathname.startsWith('/auth/'))links.add(url.pathname+url.search);
  }
 });
 await batches([...links].filter(path=>!pages.includes(path)),read);
 const protectedResponse=await fetch(new URL('/account',origin),{redirect:'manual',signal:AbortSignal.timeout(20000)});
 assert([302,303,307,308].includes(protectedResponse.status),'Anonymous account request must redirect');
 assert.equal(new URL(protectedResponse.headers.get('location'),origin).pathname,'/sign-in','Anonymous account redirect must reach sign-in');
 console.log(`PASS: ${pages.length} public pages, ${links.size} discovered internal links and anonymous account redirect at ${origin}. Visual/device/signed-in acceptance is separate.`);
})().catch(error=>{console.error(error.message);process.exitCode=1;});
