const assert = require("node:assert/strict");
const fs = require("node:fs");
const ts = require("typescript");
const source = fs.readFileSync("lib/demo/model.ts", "utf8");
const compiled = ts.transpileModule(source, {
  compilerOptions: { module: ts.ModuleKind.CommonJS },
}).outputText;
const demoModule = { exports: {} };
new Function("module", "exports", compiled)(demoModule, demoModule.exports);
const { initialDemoState, transition, restoreDemo } = demoModule.exports;
const action = (type, issue) => ({ type, issue, actor: "Test demo persona" });
let s = initialDemoState();
assert.equal(
  transition(s, action("APPROVE")),
  s,
  "Approval requires a submitted application",
);
for (const type of [
  "BOOK",
  "CONFIRM",
  "DOCUMENT",
  "APPLY",
  "APPROVE",
  "SIGN",
  "MOVE_IN",
])
  s = transition(s, action(type));
assert.equal(s.application, "moved_in");
assert.equal(s.viewing, "confirmed");
assert.equal(s.activity.length, 8);
assert.equal(
  transition(s, action("MOVE_IN")),
  s,
  "Repeated move-in does not create duplicate events",
);
s = transition(s, action("REPORT", "A fictional dripping tap"));
assert.equal(
  transition(s, action("COMPLETE")),
  s,
  "Completion requires authorized check-in",
);
for (const type of [
  "ASSIGN",
  "CHECK_IN",
  "COMPLETE",
  "SUBMIT_INVOICE",
  "CHECK_OUT",
  "CLOSE",
  "APPROVE_INVOICE",
  "PAY_INVOICE",
])
  s = transition(s, action(type));
assert.equal(s.work, "closed");
assert.equal(s.checkedOut, true);
assert.equal(s.vendor, "paid");
assert.equal(transition(s, action("PAY_INVOICE")), s);
s = transition(s, action("RECEIVE_CHEQUE"));
assert.equal(s.rentPaid, false);
assert.equal(
  transition(s, action("PAY_RENT")),
  s,
  "Cheque and simulated direct payment cannot both post",
);
s = transition(s, action("DEPOSIT_CHEQUE"));
assert.equal(
  s.rentPaid,
  false,
  "Depositing a cheque does not clear the balance",
);
s = transition(s, action("CLEAR_CHEQUE"));
assert.equal(s.rentPaid, true);
assert.equal(transition(s, action("CLEAR_CHEQUE")), s, "Clearance posts once");
assert.deepEqual(restoreDemo(JSON.stringify(s)), s);
assert.equal(restoreDemo("{broken"), null);
assert.equal(restoreDemo(JSON.stringify({ ...s, work: "unexpected" })), null);
assert.equal(restoreDemo(JSON.stringify({ ...s, rentPaid: "true" })), null);
assert.equal(restoreDemo(JSON.stringify({ ...s, activity: [null] })), null);
console.log(
  "PASS: leasing lifecycle, maintenance handoffs, invoice flow, cheque posting, duplicate guards, session restoration",
);
