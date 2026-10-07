const fs=require('fs'),ts=require('typescript'),assert=require('node:assert/strict');
let user=null,error=null,calls=[];
const client={auth:{getUser:async()=>({data:{user},error:null})},rpc:async(name,args)=>{calls.push({name,args});return {data:name==='submit_rental_application'?'55667788-0000-4000-8000-000000000099':{status:'under_review',version:2},error}}};
const cache={};function load(path){if(cache[path])return cache[path];const module={exports:{}};const req=name=>{
 if(name==='next/server')return {NextResponse:{json:(body,options)=>new Response(JSON.stringify(body),{...options,headers:{'Content-Type':'application/json',...options?.headers}})}};
 if(name==='@/lib/supabase/server')return {createClient:async()=>client};
 if(name.startsWith('@/lib/'))return load(name.slice(2)+'.ts');
 throw Error(`Unexpected import ${name}`);
};new Function('require','exports','module',ts.transpileModule(fs.readFileSync(path,'utf8'),{compilerOptions:{module:ts.ModuleKind.CommonJS,target:ts.ScriptTarget.ES2022}}).outputText)(req,module.exports,module);cache[path]=module.exports;return module.exports;}
const {POST,PATCH}=load('app/api/applications/route.ts'),{applicationInput,applicationTransition,jamaicaToday}=load('lib/applications/validation.ts');
const id='55667788-0000-4000-8000-000000000001';const body={request_id:id,listing_id:id,enquiry_id:null,contact_name:'Test Applicant',phone:'',household_size:2,desired_move_in:'2026-11-01',message:'Please review my rental application.',consent:true,user_id:'spoof',organization_id:'spoof',contact_email:'spoof@example.invalid',status:'approved',rent_jmd_snapshot:1};
function request(data,method='POST',origin='http://127.0.0.1:3001'){return new Request('http://localhost:3001/api/applications',{method,headers:{host:'127.0.0.1:3001',origin,'Content-Type':'application/json'},body:JSON.stringify(data)});}
(async()=>{
 const parsed=applicationInput(body);for(const key of ['user_id','organization_id','contact_email','status','rent_jmd_snapshot'])assert.equal(parsed[key],undefined);
 for(const bad of [{consent:false},{household_size:0},{household_size:21},{household_size:1.5},{desired_move_in:'2026-02-30'},{desired_move_in:'2026-13-01'},{enquiry_id:'invalid'},{message:'x'.repeat(2001)}])assert.throws(()=>applicationInput({...body,...bad}));
 assert.equal(jamaicaToday(new Date('2026-10-07T03:00:00Z')),'2026-10-06');
 assert.throws(()=>applicationTransition({id,request_id:id,version:1,action:'approve',message:'Premature approval.'}));
 assert.throws(()=>applicationTransition({id,request_id:id,version:0,action:'reply',message:'My clarification.'}));
 assert.equal((await POST(request(body))).status,401);assert.equal(calls.length,0);
 assert.equal((await POST(request(body,'POST','https://foreign.example'))).status,403);
 user={id,email_confirmed_at:null};assert.equal((await POST(request(body))).status,401);
 user={id,email_confirmed_at:'2026-10-06T12:00:00Z'};let response=await POST(request(body));assert.equal(response.status,201);assert.deepEqual(calls.at(-1),{name:'submit_rental_application',args:parsed});assert.equal(response.headers.get('Cache-Control'),'no-store');
 error={code:'23505'};assert.equal((await POST(request(body))).status,409);
 error={code:'P0001'};assert.equal((await POST(request(body))).status,429);
 const update={id,request_id:id,version:1,action:'start_review',message:'Reviewing this application.',actor_user_id:'spoof'};error=null;response=await PATCH(request(update,'PATCH'));assert.equal(response.status,200);assert.deepEqual(calls.at(-1),{name:'transition_rental_application',args:{p_id:id,p_request_id:id,p_expected_version:1,p_action:'start_review',p_message:'Reviewing this application.'}});
 error={code:'42501'};assert.equal((await PATCH(request(update,'PATCH'))).status,403);error={code:'40001'};assert.equal((await PATCH(request(update,'PATCH'))).status,409);
 console.log('PASS: application consent/household/calendar/UUID bounds, Jamaica date, ignored identity/quote/status spoofing, verified-auth/origin guards and trusted review RPC/conflict responses');
})().catch(error=>{console.error(error);process.exitCode=1});
