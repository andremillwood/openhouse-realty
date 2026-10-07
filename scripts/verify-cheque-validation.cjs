const fs=require('fs'),ts=require('typescript'),assert=require('node:assert/strict'),m={exports:{}};
new Function('exports','module',ts.transpileModule(fs.readFileSync('lib/finance/cheque-validation.ts','utf8'),{compilerOptions:{module:ts.ModuleKind.CommonJS,target:ts.ScriptTarget.ES2022}}).outputText)(m.exports,m);
const {chequeInput}=m.exports,id='44556600-0000-4000-8000-000000000001',body={request_id:id,action:'receive',cheque_id:null,version:0,property_id:id,payer_name:' Approved payer ',bank_name:' Approved bank ',cheque_reference:' CHQ-101 ',amount_minor:10001,evidence_id:null,bank_reference:null,reason:'Approved custody receipt',approved:true,organization_id:'spoof',received_by:'spoof',state:'cleared',posted_journal_id:id};
const r=chequeInput(body);assert.equal(r.p_payer_name,'Approved payer');assert.equal(r.p_bank_name,'Approved bank');assert.equal(r.p_cheque_reference,'CHQ-101');assert.equal(r.p_amount_minor,10001);for(const key of ['organization_id','received_by','state','posted_journal_id'])assert(!(key in r));
for(const patch of [{request_id:'bad'},{action:'paid'},{cheque_id:id},{version:1},{version:-1},{version:0.5},{version:'0'},{version:2147483647},{property_id:null},{bank_name:'x'},{payer_name:'x'},{cheque_reference:''},{cheque_reference:'line\nspoof'},{amount_minor:0},{amount_minor:-1},{amount_minor:1.2},{amount_minor:'10001'},{amount_minor:Infinity},{amount_minor:100000000000000},{approved:false},{reason:'tiny'},{evidence_id:id},{bank_reference:'bank-ref'}])assert.throws(()=>chequeInput({...body,...patch}));
assert.equal(chequeInput({...body,amount_minor:99999999999999}).p_amount_minor,99999999999999);
for(const action of ['record_deposit','confirm_clear','record_return','cancel']){
 const reply={...body,action,cheque_id:id,version:1,property_id:null,payer_name:null,bank_name:null,cheque_reference:null,amount_minor:null,evidence_id:action==='cancel'?null:id,bank_reference:action==='cancel'?null:'BANK-101'};
 assert.equal(chequeInput(reply).p_cheque_id,id);assert.equal(chequeInput(reply).p_amount_minor,null);
 for(const patch of [{cheque_id:null},{version:0},{payer_name:'changed'},{property_id:id},{amount_minor:10001},{bank_name:'changed'}])assert.throws(()=>chequeInput({...reply,...patch}));
 if(action!=='cancel')for(const patch of [{evidence_id:null},{evidence_id:'bad'},{bank_reference:'x'},{bank_reference:'bad\nreference'}])assert.throws(()=>chequeInput({...reply,...patch}));
 else assert.throws(()=>chequeInput({...reply,evidence_id:id}));
}
for(const value of [null,[],true,'cheque'])assert.throws(()=>chequeInput(value));
console.log('PASS: cheque exact JMD receipt bounds, immutable custody details, explicit approval/revisions, bank evidence/reference requirements and accounting authority exclusion');
