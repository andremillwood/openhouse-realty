const assert=require('node:assert/strict'),{bootstrapSQL}=require('./generate-admin-bootstrap.cjs');
const organizationId='99001122-0000-4000-8000-000000000001';
const sql=bootstrapSQL({organizationId,email:"o'hara@example.invalid"});assert.match(sql,/o''hara@example.invalid/);assert.match(sql,/email_confirmed_at is not null/);assert.match(sql,/for update/);assert.match(sql,/Existing membership cannot be reassigned/);assert.match(sql,/An administrator already exists/);assert(sql.startsWith('-- Run only'));assert(sql.endsWith('commit;\n'));
for(const input of [{},{organizationId,email:'bad'},{organizationId:'bad',email:'approved@example.invalid'},{organizationId,email:'a@b.invalid\nselect 1'},{organizationId,email:'x'.repeat(255)+'@example.invalid'}])assert.throws(()=>bootstrapSQL(input));
console.log('PASS: administrator bootstrap input bounds, safe SQL literals, verified account and existing-membership guards');
