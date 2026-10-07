"use client";

import Link from "next/link";
import { useEffect, useState } from "react";
import { SiteHeader } from "@/components/discovery/site-header";
import { PropertyMap } from "@/components/discovery/property-map";
import { homes, photoUrl } from "@/lib/discovery/data";
import {
  initialDemoState,
  restoreDemo,
  roles,
  transition,
  type DemoRole,
  type DemoAction,
  type DemoState,
} from "@/lib/demo/model";

const storageKey = "openhouse-demo-v1";
const label = (value: string) =>
  value.replaceAll("_", " ").replace(/^./, (s) => s.toUpperCase());
const money = (amount: number) => `JMD ${amount.toLocaleString("en-JM")}`;
const tabs: Record<DemoRole, string[]> = {
  prospect: ["Overview", "Application", "Documents"],
  realtor: ["Overview", "Leasing", "Portfolio"],
  seller: ["Overview", "Marketing", "Documents"],
  resident: ["Overview", "Maintenance", "Finance", "Documents"],
  manager: ["Overview", "Leasing", "Maintenance", "Portfolio"],
  contractor: ["Overview", "Maintenance", "Finance"],
  security: ["Overview", "Access"],
  finance: ["Overview", "Finance"],
  owner: ["Overview", "Portfolio", "Finance"],
};
function Panel({
  title,
  children,
  kicker,
}: {
  title: string;
  children: React.ReactNode;
  kicker?: string;
}) {
  return (
    <section className="demo-panel">
      {kicker && <p className="eyebrow">{kicker}</p>}
      <h2>{title}</h2>
      {children}
    </section>
  );
}
function Stat({ value, label: caption }: { value: string; label: string }) {
  return (
    <div className="demo-stat">
      <strong>{value}</strong>
      <span>{caption}</span>
    </div>
  );
}
function Badge({ value }: { value: string }) {
  return <span className={`demo-badge badge-${value}`}>{label(value)}</span>;
}

function DemoActionButton({
  type,
  children,
  disabled = false,
  ready,
  onAction,
}: {
  type: DemoAction["type"];
  children: React.ReactNode;
  disabled?: boolean;
  ready: boolean;
  onAction: (type: DemoAction["type"]) => void;
}) {
  return (
    <button
      className="demo-action"
      disabled={disabled || !ready}
      onClick={() => onAction(type)}
    >
      {children}
    </button>
  );
}

export function DemoWorkspace({ initialRole }: { initialRole?: DemoRole }) {
  const [role, setRole] = useState<DemoRole>(initialRole ?? "prospect");
  const [chooser, setChooser] = useState(!initialRole);
  const [tab, setTab] = useState("Overview");
  const [state, setState] = useState<DemoState>(initialDemoState);
  const [ready, setReady] = useState(false);
  const [storageAvailable, setStorageAvailable] = useState(true);
  const [issue, setIssue] = useState(
    "Kitchen tap is dripping. Please arrange a repair.",
  );
  const [notice, setNotice] = useState("");
  const [guide, setGuide] = useState(false);
  const persona = roles.find((r) => r.id === role)!;
  useEffect(() => {
    try {
      const restored = restoreDemo(sessionStorage.getItem(storageKey));
      if (restored) setState(restored);
    } catch {
      setStorageAvailable(false);
    }
    setReady(true);
  }, []);
  useEffect(() => {
    if (ready)
      try {
        sessionStorage.setItem(storageKey, JSON.stringify(state));
      } catch {
        setStorageAvailable(false);
      }
  }, [state, ready]);
  function choose(next: DemoRole, nextTab = "Overview") {
    setRole(next);
    setTab(nextTab);
    setChooser(false);
    window.history.replaceState(null, "", `/demo?role=${next}`);
    setNotice(`Now exploring as ${roles.find((r) => r.id === next)!.name}.`);
  }
  function act(type: DemoAction["type"]) {
    const next = transition(state, {
      type,
      actor: `${persona.person} · ${persona.name}`,
      issue,
    });
    if (next !== state) {
      setState(next);
      setNotice(next.activity[0].text);
    }
  }

  const balance = state.rentPaid ? 0 : 305000;
  const occupancy = state.application === "moved_in" ? 12 : 11;
  const workActive = state.work !== "none" && state.work !== "closed";
  const leaseStages = ["submitted", "approved", "signed", "moved_in"];
  const workStages = ["reported", "assigned", "on_site", "completed", "closed"];
  const applicationPanel = (
    <Panel title="From viewing to move-in" kicker="DANIEL · RESIDENCE 8C">
      <div className="demo-record">
        <span>Viewing</span>
        <Badge value={state.viewing} />
      </div>
      <div className="demo-record">
        <span>Application</span>
        <Badge value={state.application} />
      </div>
      <ol className="demo-steps">
        {leaseStages.map((stage, i) => (
          <li
            key={stage}
            data-complete={leaseStages.indexOf(state.application) >= i}
          >
            <span>{i + 1}</span>
            {label(stage)}
          </li>
        ))}
      </ol>
      {role === "prospect" ? (
        <>
          <div className="demo-actions">
            <DemoActionButton
              ready={ready}
              onAction={act}
              type="BOOK"
              disabled={state.viewing !== "none"}
            >
              Request demo viewing
            </DemoActionButton>
            <DemoActionButton
              ready={ready}
              onAction={act}
              type="DOCUMENT"
              disabled={state.documentReady}
            >
              Use sample document checklist
            </DemoActionButton>
            <DemoActionButton
              ready={ready}
              onAction={act}
              type="APPLY"
              disabled={
                state.viewing !== "confirmed" ||
                !state.documentReady ||
                state.application !== "none"
              }
            >
              Submit demo application
            </DemoActionButton>
            <DemoActionButton
              ready={ready}
              onAction={act}
              type="SIGN"
              disabled={state.application !== "approved"}
            >
              Simulate lease signing
            </DemoActionButton>
            <DemoActionButton
              ready={ready}
              onAction={act}
              type="MOVE_IN"
              disabled={state.application !== "signed"}
            >
              Complete demo move-in
            </DemoActionButton>
          </div>
          <p className="demo-hint">
            Switch to Realtor to confirm a requested viewing, then Management to
            review a submitted application. Signing here is a simulation.
          </p>
        </>
      ) : (
        <>
          <div className="demo-actions">
            {role === "realtor" && (
              <DemoActionButton
                ready={ready}
                onAction={act}
                type="CONFIRM"
                disabled={state.viewing !== "requested"}
              >
                Confirm demo viewing
              </DemoActionButton>
            )}
            {role === "manager" && (
              <DemoActionButton
                ready={ready}
                onAction={act}
                type="APPROVE"
                disabled={state.application !== "submitted"}
              >
                Approve demo application
              </DemoActionButton>
            )}
          </div>
          <p className="demo-hint">
            This same record appears in the prospect’s workspace. No real
            applicant is screened or approved.
          </p>
        </>
      )}
    </Panel>
  );
  const maintenancePanel = (
    <Panel title="One request. Every handoff." kicker="LESLIE’S HOME · UNIT 4B">
      <div className="demo-record">
        <span>Work order OH-104</span>
        <Badge value={state.work} />
      </div>
      {state.issue && <p className="demo-issue">{state.issue}</p>}
      <ol className="demo-steps">
        {workStages.map((stage, i) => (
          <li key={stage} data-complete={workStages.indexOf(state.work) >= i}>
            <span>{i + 1}</span>
            {label(stage)}
          </li>
        ))}
      </ol>
      {role === "resident" && (
        <>
          <label className="demo-field">
            Describe the sample issue
            <textarea
              maxLength={300}
              value={issue}
              onChange={(e) => setIssue(e.target.value)}
              disabled={state.work !== "none"}
            />
            <small>
              Use fictional details only; no attachments are uploaded.
            </small>
          </label>
          <div className="demo-actions">
            <DemoActionButton
              ready={ready}
              onAction={act}
              type="REPORT"
              disabled={state.work !== "none" || !issue.trim()}
            >
              Create demo service request
            </DemoActionButton>
            <DemoActionButton
              ready={ready}
              onAction={act}
              type="CLOSE"
              disabled={state.work !== "completed"}
            >
              Confirm repair and close request
            </DemoActionButton>
          </div>
        </>
      )}
      {role === "manager" && (
        <>
          <p>
            Triage: standard priority · Taylor James · Unit 4B · sample
            appointment.
          </p>
          <DemoActionButton
            ready={ready}
            onAction={act}
            type="ASSIGN"
            disabled={state.work !== "reported"}
          >
            Assign Taylor and authorize access
          </DemoActionButton>
        </>
      )}
      {role === "contractor" && (
        <>
          <p>
            {state.work === "assigned"
              ? "You are assigned. Security must check you in before work can be completed."
              : state.work === "on_site"
                ? "You are checked in. Complete the sample repair, then submit an invoice."
                : "Assignments and evidence are simulated."}
          </p>
          <div className="demo-actions">
            <DemoActionButton
              ready={ready}
              onAction={act}
              type="COMPLETE"
              disabled={state.work !== "on_site"}
            >
              Mark demo repair complete
            </DemoActionButton>
            <DemoActionButton
              ready={ready}
              onAction={act}
              type="SUBMIT_INVOICE"
              disabled={
                !["completed", "closed"].includes(state.work) ||
                state.vendor !== "none"
              }
            >
              Submit sample invoice · JMD 12,500
            </DemoActionButton>
          </div>
        </>
      )}
      {!["resident", "manager", "contractor"].includes(role) && (
        <p className="demo-hint">
          Track this shared request across resident, management, contractor, and
          security workspaces.
        </p>
      )}
      <div className="handoff-strip">
        <button onClick={() => choose("resident", "Maintenance")}>
          Resident
        </button>
        <span>→</span>
        <button onClick={() => choose("manager", "Maintenance")}>
          Manager
        </button>
        <span>→</span>
        <button onClick={() => choose("security", "Access")}>Security</button>
        <span>→</span>
        <button onClick={() => choose("contractor", "Maintenance")}>
          Contractor
        </button>
      </div>
    </Panel>
  );
  const accessPanel = (
    <Panel
      title="Expected. Authorized. Accounted for."
      kicker="SECURITY · SITE ACCESS"
    >
      <div className="demo-record">
        <span>Taylor James · Contractor</span>
        <Badge
          value={
            state.work === "none" || state.work === "reported"
              ? "not authorized"
              : state.checkedOut
                ? "checked out"
                : state.work === "assigned"
                  ? "expected"
                  : "on site"
          }
        />
      </div>
      <p>
        Destination: Unit 4B · job OH-104. Authorization is created when
        Management assigns the request.
      </p>
      <div className="demo-actions">
        <DemoActionButton
          ready={ready}
          onAction={act}
          type="CHECK_IN"
          disabled={state.work !== "assigned"}
        >
          Check contractor in
        </DemoActionButton>
        <DemoActionButton
          ready={ready}
          onAction={act}
          type="CHECK_OUT"
          disabled={
            !["completed", "closed"].includes(state.work) || state.checkedOut
          }
        >
          Check contractor out
        </DemoActionButton>
      </div>
      <p className="demo-hint">
        A real access workflow will verify identity, authorization, time
        windows, and audit records. This demo uses one fictional contractor.
      </p>
      <button
        className="text-button"
        onClick={() => choose("manager", "Maintenance")}
      >
        Review management authorization ↗
      </button>
    </Panel>
  );
  const ledgerPanel = (
    <Panel
      title="A balance you can explain"
      kicker="LESLIE · UNIT 4B · DEMO BILLING CYCLE"
    >
      <div className="demo-ledger">
        <div>
          <span>Rent charge</span>
          <strong>{money(295000)}</strong>
        </div>
        <div>
          <span>Maintenance fee</span>
          <strong>{money(10000)}</strong>
        </div>
        {state.rentPaid && (
          <div>
            <span>Simulated payment · DEMO-001</span>
            <strong>−{money(305000)}</strong>
          </div>
        )}
        <div className="ledger-total">
          <span>Balance due</span>
          <strong>{money(balance)}</strong>
        </div>
      </div>
      {role === "resident" && (
        <>
          <DemoActionButton
            ready={ready}
            onAction={act}
            type="PAY_RENT"
            disabled={state.rentPaid || state.cheque !== "none"}
          >
            Simulate payment · no money moves
          </DemoActionButton>
          {state.rentPaid && (
            <div className="demo-receipt">
              <strong>Demo receipt DEMO-001</strong>
              <p>
                JMD 305,000 · simulated payment · not proof of a real
                transaction.
              </p>
            </div>
          )}
        </>
      )}
      <p className="demo-hint">
        Rent and maintenance charges share a ledger. No card details are
        collected.
      </p>
    </Panel>
  );
  const financePanel = (
    <>
      {ledgerPanel}
      {role === "finance" && (
        <div className="demo-two-col">
          <Panel title="Cheque clearance" kicker="SAMPLE CHEQUE · CHQ-DEMO-01">
            <Badge value={state.cheque} />
            <p>
              JMD 305,000. Receiving or depositing a cheque does not reduce the
              sample balance; clearing it posts the payment once.
            </p>
            <div className="demo-actions">
              <DemoActionButton
                ready={ready}
                onAction={act}
                type="RECEIVE_CHEQUE"
                disabled={state.rentPaid || state.cheque !== "none"}
              >
                Record sample cheque
              </DemoActionButton>
              <DemoActionButton
                ready={ready}
                onAction={act}
                type="DEPOSIT_CHEQUE"
                disabled={state.cheque !== "received"}
              >
                Mark deposited
              </DemoActionButton>
              <DemoActionButton
                ready={ready}
                onAction={act}
                type="CLEAR_CHEQUE"
                disabled={state.cheque !== "deposited"}
              >
                Simulate clearance
              </DemoActionButton>
            </div>
          </Panel>
          <Panel title="Vendor invoice" kicker="TAYLOR · INV-104">
            <Badge value={state.vendor} />
            <p>
              JMD 12,500 · repair OH-104. The contractor submits this after
              completing the job.
            </p>
            <div className="demo-actions">
              <DemoActionButton
                ready={ready}
                onAction={act}
                type="APPROVE_INVOICE"
                disabled={state.vendor !== "submitted"}
              >
                Approve sample invoice
              </DemoActionButton>
              <DemoActionButton
                ready={ready}
                onAction={act}
                type="PAY_INVOICE"
                disabled={state.vendor !== "approved"}
              >
                Simulate vendor payment
              </DemoActionButton>
            </div>
            <button
              className="text-button"
              onClick={() => choose("contractor", "Maintenance")}
            >
              Open contractor workspace ↗
            </button>
          </Panel>
          <Panel title="Property tax obligation" kicker="SAMPLE OBLIGATION">
            <div className="demo-record">
              <span>Garden House · JMD 90,000</span>
              <Badge value={state.taxPaid ? "paid" : "due"} />
            </div>
            <DemoActionButton
              ready={ready}
              onAction={act}
              type="PAY_TAX"
              disabled={state.taxPaid}
            >
              Mark sample obligation paid
            </DemoActionButton>
            <p className="demo-hint">
              Tracking only. This is not a tax assessment or government payment.
            </p>
          </Panel>
        </div>
      )}
      {role === "contractor" && (
        <Panel title="Your invoice" kicker="INV-104">
          <Badge value={state.vendor} />
          <p>
            Sample repair invoice · JMD 12,500. Submit it after completing
            OH-104; Finance approves and simulates payment.
          </p>
          <DemoActionButton
            ready={ready}
            onAction={act}
            type="SUBMIT_INVOICE"
            disabled={
              !["completed", "closed"].includes(state.work) ||
              state.vendor !== "none"
            }
          >
            Submit sample invoice
          </DemoActionButton>
        </Panel>
      )}
    </>
  );
  const marketingPanel = (
    <Panel title="A clear path to market" kicker="OLIVIA · GARDEN HOUSE">
      <div className="demo-record">
        <span>Listing preparation</span>
        <Badge value={state.seller} />
      </div>
      <div className="demo-checklist">
        <p>✓ Sample property brief</p>
        <p>✓ Illustrative photography direction</p>
        <p>✓ Draft marketing plan</p>
        <p>{state.seller === "published" ? "✓" : "○"} Demo launch approval</p>
      </div>
      <div className="demo-actions">
        <DemoActionButton
          ready={ready}
          onAction={act}
          type="PROPOSAL"
          disabled={state.seller !== "review"}
        >
          Prepare sample proposal
        </DemoActionButton>
        <DemoActionButton
          ready={ready}
          onAction={act}
          type="PUBLISH"
          disabled={state.seller !== "proposal"}
        >
          Approve simulated listing launch
        </DemoActionButton>
      </div>
      <p className="demo-hint">
        Listing launch here changes only the demo. Views, offers, and enquiries
        must come from real analytics before production reporting.
      </p>
      <Link className="button-link" href="/demo/listings/kingston-family">
        Explore the sample property ↗
      </Link>
    </Panel>
  );
  const portfolioPanel = (
    <Panel title="Place matters" kicker="DEMO PORTFOLIO · APPROXIMATE AREAS">
      <PropertyMap homes={homes} />
      <div className="demo-property-links">
        {homes.map((h) => (
          <Link key={h.id} href={`/demo/listings/${h.id}`}>
            <strong>{h.title}</strong>
            <span>{h.area} ↗</span>
          </Link>
        ))}
      </div>
      <p className="demo-hint">
        Demo property pins illustrate location context. Private exact addresses
        are not shown.
      </p>
    </Panel>
  );
  const documentsPanel = (
    <Panel
      title="The right document, at the right stage"
      kicker="SAMPLE CHECKLIST"
    >
      <div className="demo-document">
        <span>Application checklist</span>
        <Badge value={state.documentReady ? "ready" : "pending"} />
      </div>
      <div className="demo-document">
        <span>Lease example</span>
        <Badge
          value={
            ["signed", "moved_in"].includes(state.application)
              ? "demo signed"
              : "sample"
          }
        />
      </div>
      <div className="demo-document">
        <span>Resident statement</span>
        <Badge value={state.rentPaid ? "demo settled" : "demo balance due"} />
      </div>
      <p className="demo-hint">
        These are checklist examples, not real documents, uploads, signatures,
        or identity records.
      </p>
      {role === "prospect" && (
        <DemoActionButton
          ready={ready}
          onAction={act}
          type="DOCUMENT"
          disabled={state.documentReady}
        >
          Mark sample checklist ready
        </DemoActionButton>
      )}
    </Panel>
  );
  const remainingPanel = (
    <Panel
      title="From walkthrough to production"
      kicker="WHAT STILL NEEDS BUILDING"
    >
      <div className="demo-backlog">
        {[
          [
            "Identity & permissions",
            "Real sign-in, invites, account recovery, role and organization membership, staff/resident authorization.",
          ],
          [
            "Live marketplace & realtors",
            "Verified property inventory, media uploads, approved map locations, actual realtor bios and service styles, persistent saves.",
          ],
          [
            "Enquiries & leasing",
            "Server form submission, Resend delivery, abuse prevention, viewing availability, calendar confirmations, applications and decisions.",
          ],
          [
            "Documents & resident lifecycle",
            "Secure storage, document access, verification, legal lease signing, deposits, move-in, renewal, and move-out.",
          ],
          [
            "Operations & security",
            "Persistent shared work orders, assignment rules, evidence uploads, SLAs, identity checks, access windows, incidents, audit logs.",
          ],
          [
            "Finance & owner reporting",
            "Payment provider, reconciled ledger, invoice approvals, cheque returns, tax evidence, receipts, trusted analytics and owner reporting.",
          ],
          [
            "Launch & mobile",
            "End-to-end permission tests, monitoring, backup/recovery, public deployment, production map provider, accessibility hardening; native app and push later.",
          ],
        ].map(([title, description]) => (
          <div key={title}>
            <h3>{title}</h3>
            <p>{description}</p>
          </div>
        ))}
      </div>
    </Panel>
  );
  const guideSteps = [
    {
      title: "1. Discover and request a viewing",
      detail: "Prospect requests a sample viewing, then Realtor confirms it.",
      done: state.viewing === "confirmed",
      role: "prospect" as DemoRole,
      tab: "Application",
    },
    {
      title: "2. Move from application to resident",
      detail:
        "Mark documents ready, apply, switch to Management to approve, then sign and move in as Prospect.",
      done: state.application === "moved_in",
      role: "prospect" as DemoRole,
      tab: "Application",
    },
    {
      title: "3. Resolve a maintenance request",
      detail:
        "Resident reports → Management assigns → Security checks in → Contractor completes → Resident confirms.",
      done: state.work === "closed",
      role: "resident" as DemoRole,
      tab: "Maintenance",
    },
    {
      title: "4. Close access and settle the vendor invoice",
      detail:
        "Security checks out; Contractor submits an invoice; Finance approves and simulates payment.",
      done: state.checkedOut && state.vendor === "paid",
      role: "security" as DemoRole,
      tab: "Access",
    },
    {
      title: "5. Explain and settle a balance",
      detail:
        "Simulate a resident payment, or walk through cheque receipt, deposit, and clearance in Finance.",
      done: state.rentPaid,
      role: "finance" as DemoRole,
      tab: "Finance",
    },
  ];

  if (chooser)
    return (
      <>
        <SiteHeader />
        <main className="demo-hub">
          <p className="eyebrow">OPEN HOUSE REALTY · INTERACTIVE WALKTHROUGH</p>
          <h1>
            One platform.
            <br />
            Every perspective.
          </h1>
          <p className="demo-hub-copy">
            Explore the full product vision through fictional profiles. Switch
            roles at any time to see the same journey from the other side.
          </p>
          <div className="demo-disclaimer">
            <strong>Demo experience</strong>
            <span>
              Fictional records, simulated actions. No login needed. No real
              emails, payments, or production changes.
            </span>
          </div>
          <div className="demo-persona-grid">
            {roles.map((r) => (
              <button
                key={r.id}
                className="demo-persona"
                onClick={() => choose(r.id)}
              >
                <span className="persona-icon" aria-hidden="true">
                  {r.icon}
                </span>
                <strong>{r.name}</strong>
                <span>{r.person} · fictional profile</span>
                <p>{r.description}</p>
                <b>Explore this role ↗</b>
              </button>
            ))}
          </div>
          <div className="demo-hub-links">
            <Link href="/demo/listings">Explore the property marketplace ↗</Link>
            <Link href="/demo/realtors">Try realtor matching ↗</Link>
            <button
              onClick={() => {
                choose("prospect", "Application");
                setGuide(true);
              }}
            >
              Start guided walkthrough ↗
            </button>
          </div>
        </main>
      </>
    );
  return (
    <div className="demo-app">
      <header className="demo-topbar">
        <Link href="/" className="brand">
          <img src="/brand/logo-blue.png" alt="Open House Realty" />
        </Link>
        <span className="demo-mode">DEMO WORKSPACE</span>
        <div className="demo-top-actions">
          <button onClick={() => setChooser(true)}>Change profile</button>
          <button
            onClick={() => {
              setState(initialDemoState());
              setIssue("Kitchen tap is dripping. Please arrange a repair.");
              setNotice(
                "Demo reset. Every sample workflow is ready to explore again.",
              );
            }}
          >
            Reset demo
          </button>
        </div>
      </header>
      <div className="demo-banner">
        Fictional people and records · simulated actions · no real email or
        money moves
        {!storageAvailable && (
          <strong> · Browser storage unavailable; this visit only</strong>
        )}
      </div>
      <div className="demo-layout">
        <aside className="demo-sidebar">
          <div className="demo-profile">
            <span className="demo-profile-avatar">
              {persona.person
                .split(" ")
                .map((n) => n[0])
                .join("")}
            </span>
            <strong>{persona.person}</strong>
            <small>{persona.name} · fictional profile</small>
          </div>
          <label className="demo-role-select">
            Explore as
            <select
              value={role}
              onChange={(e) => choose(e.target.value as DemoRole)}
            >
              {roles.map((r) => (
                <option key={r.id} value={r.id}>
                  {r.name}
                </option>
              ))}
            </select>
          </label>
          <nav aria-label="Demo workspace navigation">
            {[...tabs[role], "Activity", "What remains"].map((item) => (
              <button
                key={item}
                className={tab === item ? "current" : ""}
                aria-current={tab === item ? "page" : undefined}
                onClick={() => setTab(item)}
              >
                {item}
                <span aria-hidden="true">↗</span>
              </button>
            ))}
          </nav>
          <div className="demo-explore-links">
            <Link href="/demo/listings">Property marketplace ↗</Link>
            <Link href="/demo/realtors">Realtor matching ↗</Link>
            <button onClick={() => setGuide(!guide)}>
              Guided walkthrough {guide ? "−" : "+"}
            </button>
          </div>
        </aside>
        <main className="demo-main">
          <div className="demo-heading">
            <div>
              <p className="eyebrow">{persona.name.toUpperCase()} WORKSPACE</p>
              <h1>
                {tab === "Overview"
                  ? persona.title
                  : tab === "What remains"
                    ? "The path to a live product"
                    : tab}
              </h1>
              <p>{persona.description}</p>
            </div>
            <span className="demo-cycle">Sample cycle · Kingston, Jamaica</span>
          </div>
          <div className="demo-feedback" role="status" aria-live="polite">
            {notice || "Choose an action to explore a simulated workflow."}
          </div>
          {guide && (
            <Panel
              title="Your client walkthrough"
              kicker="FOLLOW THE SHARED RECORDS"
            >
              <div className="demo-guide">
                {guideSteps.map((step) => (
                  <button
                    key={step.title}
                    onClick={() => choose(step.role, step.tab)}
                  >
                    <span>{step.done ? "✓" : "○"}</span>
                    <div>
                      <strong>{step.title}</strong>
                      <p>{step.detail}</p>
                    </div>
                  </button>
                ))}
              </div>
            </Panel>
          )}
          {tab === "Overview" && (
            <>
              <div className="demo-stats">
                <Stat value={`${occupancy}/12`} label="Sample units occupied" />
                <Stat value={money(balance)} label="Sample resident balance" />
                <Stat
                  value={workActive ? "1" : "0"}
                  label="Active demo work orders"
                />
                <Stat
                  value={state.viewing === "none" ? "0" : "1"}
                  label="Demo viewing requests"
                />
              </div>
              <div className="demo-overview-grid">
                <Panel
                  title={`Welcome, ${persona.person.split(" ")[0]}.`}
                  kicker="YOUR NEXT ACTION"
                >
                  <p>
                    {role === "prospect"
                      ? "Find a home and a realtor who fits, then follow your application through to move-in."
                      : role === "resident"
                        ? "Your balance, maintenance progress, and home documents are all in one place."
                        : role === "owner"
                          ? "See how leasing, operations, and collections contribute to your property’s performance."
                          : "Review the same shared records and see which handoff needs your attention."}
                  </p>
                  <div className="demo-quick-links">
                    {tabs[role]
                      .filter((t) => t !== "Overview")
                      .map((t) => (
                        <button key={t} onClick={() => setTab(t)}>
                          {t} ↗
                        </button>
                      ))}
                  </div>
                  <Link className="button-link" href="/demo/listings">
                    Browse sample homes ↗
                  </Link>
                </Panel>
                <Panel
                  title="The home at the center"
                  kicker="RESIDENCE 8C · KINGSTON 6"
                >
                  <img
                    className="demo-home-photo"
                    src={photoUrl(homes[0])}
                    alt="Illustrative sample home"
                  />
                  <Link className="button-link" href="/demo/listings/residence-8c">
                    View property and neighborhood ↗
                  </Link>
                </Panel>
              </div>
              {["prospect", "realtor", "manager"].includes(role) &&
                applicationPanel}
              {role === "resident" && ledgerPanel}
              {role === "seller" && marketingPanel}
              {role === "contractor" && maintenancePanel}
              {role === "security" && accessPanel}
              {role === "finance" && financePanel}
              {role === "owner" && (
                <Panel
                  title="Owner snapshot"
                  kicker="DERIVED FROM THIS DEMO SESSION"
                >
                  <div className="demo-record">
                    <span>Occupancy</span>
                    <strong>{Math.round((occupancy / 12) * 100)}%</strong>
                  </div>
                  <div className="demo-record">
                    <span>Sample collections</span>
                    <strong>{state.rentPaid ? money(305000) : money(0)}</strong>
                  </div>
                  <div className="demo-record">
                    <span>Vendor cost paid</span>
                    <strong>
                      {state.vendor === "paid" ? money(12500) : money(0)}
                    </strong>
                  </div>
                  <div className="demo-record">
                    <span>Maintenance state</span>
                    <Badge value={state.work} />
                  </div>
                  <p className="demo-hint">
                    This is a fictional portfolio summary, not a verified
                    financial statement.
                  </p>
                </Panel>
              )}
            </>
          )}
          {["Application", "Leasing"].includes(tab) && applicationPanel}
          {tab === "Maintenance" && maintenancePanel}
          {tab === "Access" && accessPanel}
          {tab === "Finance" && financePanel}
          {tab === "Marketing" && marketingPanel}
          {tab === "Portfolio" && portfolioPanel}
          {tab === "Documents" && documentsPanel}
          {tab === "Activity" && (
            <Panel title="One shared activity trail" kicker="LOCAL DEMO EVENTS">
              <ol className="demo-activity">
                {state.activity.map((event, i) => (
                  <li key={`${i}-${event.text}`}>
                    <span aria-hidden="true">◇</span>
                    <div>
                      <strong>{event.text}</strong>
                      <small>{event.actor} · simulated event</small>
                    </div>
                  </li>
                ))}
              </ol>
            </Panel>
          )}
          {tab === "What remains" && remainingPanel}
          <p className="demo-bottom-note">
            Demo state stays in this browser tab session and follows you between
            roles. Each client browser has its own walkthrough. Reset returns
            all sample records to the start.
          </p>
        </main>
      </div>
    </div>
  );
}
