const fs=require('fs'),ts=require('typescript'),assert=require('node:assert/strict');
function load(path){const m={exports:{}};new Function('require','exports','module',ts.transpileModule(fs.readFileSync(path,'utf8'),{compilerOptions:{module:ts.ModuleKind.CommonJS,target:ts.ScriptTarget.ES2022}}).outputText)(n=>n.startsWith('@/')?load(n.slice(2)+'.ts'):require(n),m.exports,m);return m.exports;}
const {activationReadiness:check}=load('lib/leases/activation-readiness.ts');
const base={currentApproval:true,heldReservation:true,execution:{verified:true,currentDraft:true,documentHash:'a'.repeat(64)},deposit:{verified:true,requiredMinor:120000,settledMinor:120000,currency:'JMD'},preparation:['unit_readiness','utilities','access_preparation'].map(kind=>({kind,version:1,state:'ready',evidenceReference:'Approved inspection'}))};
assert.equal(check(base).eligible,true);
for(const field of ['currentApproval','heldReservation'])assert.equal(check({...base,[field]:false}).eligible,false);
for(const execution of [null,{...base.execution,verified:false},{...base.execution,currentDraft:false},{...base.execution,documentHash:'receipt'}])assert.equal(check({...base,execution}).eligible,false);
for(const deposit of [null,{...base.deposit,verified:false},{...base.deposit,settledMinor:119999},{...base.deposit,requiredMinor:-1},{...base.deposit,settledMinor:NaN},{...base.deposit,currency:'USD'}])assert.equal(check({...base,deposit}).eligible,false);
assert.equal(check({...base,preparation:base.preparation.slice(1)}).eligible,false);
for(const state of ['pending','blocked'])assert.equal(check({...base,preparation:[...base.preparation,{...base.preparation[0],version:2,state}]}).eligible,false);
assert.equal(check({...base,preparation:[...base.preparation,base.preparation[0]]}).eligible,false);
assert.equal(check({...base,preparation:[...base.preparation,{...base.preparation[0],version:0}]}).eligible,false);
assert.equal(check({...base,preparation:[...base.preparation,{...base.preparation[0],version:2,evidenceReference:''}]}).eligible,false);
assert(Object.isFrozen(check(base).blockers));
console.log('PASS: activation eligibility requires current approval/reservation, verified execution/deposit and unambiguous latest ready evidence; later blocked decisions override earlier readiness');
