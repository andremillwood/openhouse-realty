const {spawnSync}=require('node:child_process');
const fs=require('node:fs');
const scripts=JSON.parse(fs.readFileSync('package.json','utf8')).scripts;
const checks=Object.keys(scripts).filter(name=>name.startsWith('test:'));
let failed=0;
for(const name of checks){
 const result=spawnSync('npm',['run',name],{encoding:'utf8',timeout:120000,maxBuffer:2*1024*1024});
 if(result.status!==0){failed++;console.error(`FAIL ${name}\n${result.stdout||''}\n${result.stderr||''}\n${result.error?.message||''}`);}else console.log(`PASS ${name}`);
}
console.log(`${checks.length-failed}/${checks.length} verification groups passed.`);
process.exitCode=failed?1:0;
