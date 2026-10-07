const fs=require('fs'),ts=require('typescript'),assert=require('node:assert/strict');const m={exports:{}};new Function('exports','module',ts.transpileModule(fs.readFileSync('lib/finance/money.ts','utf8'),{compilerOptions:{module:ts.ModuleKind.CommonJS,target:ts.ScriptTarget.ES2022}}).outputText)(m.exports,m);const {jmdMinor,formatJmdMinor}=m.exports;
for(const [input,cents] of [['0',0],['0.01',1],['1.1',110],['100.01',10001],['999999999999.99',99999999999999]])assert.equal(jmdMinor(input),cents);
for(const input of ['1.001','1,000','-1','1e2','NaN','Infinity','01','1000000000000','', '.1'])assert.throws(()=>jmdMinor(input));
assert.equal(formatJmdMinor('9999999999999900'),'JMD 99,999,999,999,999.00');assert.equal(formatJmdMinor('-1'),'-JMD 0.01');
console.log('PASS: exact JMD decimal parsing, boundary amounts, invalid-format rejection and large-total formatting');
