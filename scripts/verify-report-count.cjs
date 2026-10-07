const fs=require('fs'),ts=require('typescript'),assert=require('node:assert/strict');
const moduleValue={exports:{}};
new Function('exports',ts.transpileModule(fs.readFileSync('lib/reports/count.ts','utf8'),{compilerOptions:{module:ts.ModuleKind.CommonJS,target:ts.ScriptTarget.ES2022}}).outputText)(moduleValue.exports);
const {reportCount}=moduleValue.exports;
(async()=>{
 for(const count of [0,12,Number.MAX_SAFE_INTEGER])assert.equal(await reportCount(Promise.resolve({count,error:null})),count);
 for(const count of [null,undefined,-1,1.5,NaN,Infinity,Number.MAX_SAFE_INTEGER+1,'12'])assert.equal(await reportCount(Promise.resolve({count,error:null})),null);
 assert.equal(await reportCount(Promise.resolve({count:12,error:{message:'private database detail'}})),null);
 const results=await Promise.all([reportCount(Promise.reject(new Error('private transport detail'))),reportCount(Promise.resolve({count:7,error:null}))]);
 assert.deepEqual(results,[null,7]);
 assert.equal(await reportCount({then(){throw new Error('thenable transport failure')}}),null);
 console.log('PASS: independent report rejection recovery, nonnegative exact count validation and valid zero retention');
})().catch(error=>{console.error(error);process.exitCode=1});
