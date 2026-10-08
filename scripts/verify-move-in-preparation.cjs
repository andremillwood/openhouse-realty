const fs=require('fs'),ts=require('typescript'),assert=require('node:assert/strict');
function load(path){const m={exports:{}};new Function('require','exports','module',ts.transpileModule(fs.readFileSync(path,'utf8'),{compilerOptions:{module:ts.ModuleKind.CommonJS,target:ts.ScriptTarget.ES2022}}).outputText)(n=>n.startsWith('@/')?load(n.slice(2)+'.ts'):require(n),m.exports,m);return m.exports;}
const {moveInPreparationInput:parse,moveInPreparationKinds:kinds,moveInPreparationStates:states}=load('lib/leases/move-in.ts');const id='66117788-0000-4000-8000-000000000001';
const base={draft_id:id,draft_version:2,kind:'unit_readiness',version:0,state:'pending',evidence_reference:'',reason:'  Ready for inspection  ',request_id:id,approved:true};
assert(Object.isFrozen(parse(base)));assert.equal(parse(base).p_reason,'Ready for inspection');assert.equal(base.reason,'  Ready for inspection  ');
for(const kind of kinds)for(const state of states){assert.equal(parse({...base,kind,state,evidence_reference:state==='ready'?'Inspection OH-100':''}).p_state,state);}
for(const bad of [null,[],{}, {...base,approved:false},{...base,draft_id:'bad'},{...base,version:-1},{...base,version:1.5},{...base,draft_version:0},{...base,version:2147483646},{...base,state:'active'},{...base,kind:'deposit_paid'},{...base,state:'ready'},{...base,reason:'x'},{...base,evidence_reference:'x'.repeat(501)}])assert.throws(()=>parse(bad));
for(const key of ['organization_id','user_id','tenant_id','unit_id','signed_lease','deposit_paid','rent_minor','resident_access'])assert.throws(()=>parse({...base,[key]:true}));
console.log('PASS: move-in operational item/status bounds, zero/current revisions, evidence required for readiness, explicit approval and rejection of activation/payment/identity spoofing');
