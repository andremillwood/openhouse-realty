export const roles = [
  {
    id: "prospect",
    name: "Prospect",
    person: "Daniel Brooks",
    title: "Your next chapter",
    description: "Discover homes, request a tour, and follow an application.",
    icon: "⌂",
  },
  {
    id: "realtor",
    name: "Realtor",
    person: "Avery Campbell",
    title: "Relationships, moving forward",
    description: "Manage matches, viewing requests, and the prospect pipeline.",
    icon: "◇",
  },
  {
    id: "seller",
    name: "Seller / landlord",
    person: "Olivia Grant",
    title: "Your property, in perspective",
    description: "Follow listing preparation, demand, and next actions.",
    icon: "▥",
  },
  {
    id: "resident",
    name: "Resident",
    person: "Leslie Morgan",
    title: "Home, taken care of",
    description: "See your balance, documents, and maintenance progress.",
    icon: "⌘",
  },
  {
    id: "manager",
    name: "Management",
    person: "Chris Reid",
    title: "A clearer view of every property",
    description: "Triage requests, coordinate leasing, and assign work.",
    icon: "▦",
  },
  {
    id: "contractor",
    name: "Contractor",
    person: "Taylor James",
    title: "The right context for the job",
    description: "See assignments, access status, and completion steps.",
    icon: "⚒",
  },
  {
    id: "security",
    name: "Security",
    person: "Sam Clarke",
    title: "Know who is expected",
    description: "Review authorized visits and track contractor presence.",
    icon: "⛨",
  },
  {
    id: "finance",
    name: "Finance",
    person: "Casey Lewis",
    title: "Every balance has a story",
    description:
      "Explore ledgers, cheque clearance, invoices, and tax tracking.",
    icon: "▤",
  },
  {
    id: "owner",
    name: "Owner",
    person: "Robin Bennett",
    title: "The picture behind the property",
    description: "Understand occupancy, collections, and operating activity.",
    icon: "◷",
  },
] as const;
export type DemoRole = (typeof roles)[number]["id"];
export type DemoState = {
  version: 1;
  viewing: "none" | "requested" | "confirmed";
  application: "none" | "submitted" | "approved" | "signed" | "moved_in";
  seller: "review" | "proposal" | "published";
  work: "none" | "reported" | "assigned" | "on_site" | "completed" | "closed";
  issue: string;
  checkedOut: boolean;
  rentPaid: boolean;
  cheque: "none" | "received" | "deposited" | "cleared";
  vendor: "none" | "submitted" | "approved" | "paid";
  taxPaid: boolean;
  documentReady: boolean;
  activity: { text: string; actor: string }[];
};
export function initialDemoState(): DemoState {
  return {
    version: 1,
    viewing: "none",
    application: "none",
    seller: "review",
    work: "none",
    issue: "",
    checkedOut: false,
    rentPaid: false,
    cheque: "none",
    vendor: "none",
    taxPaid: false,
    documentReady: false,
    activity: [
      {
        text: "Demo workspace ready. All names and records are fictional.",
        actor: "Open House demo",
      },
    ],
  };
}
export type DemoAction = {
  type:
    | "BOOK"
    | "CONFIRM"
    | "DOCUMENT"
    | "APPLY"
    | "APPROVE"
    | "SIGN"
    | "MOVE_IN"
    | "PROPOSAL"
    | "PUBLISH"
    | "REPORT"
    | "ASSIGN"
    | "CHECK_IN"
    | "COMPLETE"
    | "CHECK_OUT"
    | "CLOSE"
    | "PAY_RENT"
    | "RECEIVE_CHEQUE"
    | "DEPOSIT_CHEQUE"
    | "CLEAR_CHEQUE"
    | "SUBMIT_INVOICE"
    | "APPROVE_INVOICE"
    | "PAY_INVOICE"
    | "PAY_TAX";
  actor: string;
  issue?: string;
};
export function transition(state: DemoState, action: DemoAction): DemoState {
  let patch: Partial<DemoState> | undefined;
  let text = "";
  switch (action.type) {
    case "BOOK":
      if (state.viewing === "none") {
        patch = { viewing: "requested" };
        text = "Daniel requested a viewing at Residence 8C.";
      }
      break;
    case "CONFIRM":
      if (state.viewing === "requested") {
        patch = { viewing: "confirmed" };
        text = "Avery confirmed Daniel’s demo viewing.";
      }
      break;
    case "DOCUMENT":
      if (!state.documentReady) {
        patch = { documentReady: true };
        text = "Sample application checklist marked ready. No files uploaded.";
      }
      break;
    case "APPLY":
      if (
        state.viewing === "confirmed" &&
        state.documentReady &&
        state.application === "none"
      ) {
        patch = { application: "submitted" };
        text = "Daniel submitted a simulated application for Residence 8C.";
      }
      break;
    case "APPROVE":
      if (state.application === "submitted") {
        patch = { application: "approved" };
        text = "Management approved the simulated application.";
      }
      break;
    case "SIGN":
      if (state.application === "approved") {
        patch = { application: "signed" };
        text = "Demo lease marked signed. No legal agreement was executed.";
      }
      break;
    case "MOVE_IN":
      if (state.application === "signed") {
        patch = { application: "moved_in" };
        text = "Daniel’s demo move-in completed; occupancy updated.";
      }
      break;
    case "PROPOSAL":
      if (state.seller === "review") {
        patch = { seller: "proposal" };
        text = "Sample marketing proposal prepared for Olivia’s Garden House.";
      }
      break;
    case "PUBLISH":
      if (state.seller === "proposal") {
        patch = { seller: "published" };
        text =
          "Olivia approved the demo listing launch. No public listing changed.";
      }
      break;
    case "REPORT":
      if (state.work === "none" && action.issue?.trim()) {
        patch = { work: "reported", issue: action.issue.trim().slice(0, 300) };
        text = "Leslie created demo maintenance request OH-104.";
      }
      break;
    case "ASSIGN":
      if (state.work === "reported") {
        patch = { work: "assigned" };
        text =
          "Management assigned OH-104 to Taylor and authorized a site visit.";
      }
      break;
    case "CHECK_IN":
      if (state.work === "assigned") {
        patch = { work: "on_site" };
        text = "Security checked Taylor in for OH-104 at Unit 4B.";
      }
      break;
    case "COMPLETE":
      if (state.work === "on_site") {
        patch = { work: "completed" };
        text = "Taylor marked OH-104 completed; resident confirmation pending.";
      }
      break;
    case "CHECK_OUT":
      if (
        (state.work === "completed" || state.work === "closed") &&
        !state.checkedOut
      ) {
        patch = { checkedOut: true };
        text = "Security checked Taylor out; no contractor remains onsite.";
      }
      break;
    case "CLOSE":
      if (state.work === "completed") {
        patch = { work: "closed" };
        text = "Leslie confirmed the repair and closed OH-104.";
      }
      break;
    case "PAY_RENT":
      if (!state.rentPaid && state.cheque === "none") {
        patch = { rentPaid: true };
        text =
          "Simulated JMD 305,000 payment posted to Leslie’s demo ledger. No money moved.";
      }
      break;
    case "RECEIVE_CHEQUE":
      if (!state.rentPaid && state.cheque === "none") {
        patch = { cheque: "received" };
        text =
          "Demo cheque recorded for JMD 305,000; balance remains due until clearance.";
      }
      break;
    case "DEPOSIT_CHEQUE":
      if (state.cheque === "received") {
        patch = { cheque: "deposited" };
        text = "Demo cheque marked deposited; clearance pending.";
      }
      break;
    case "CLEAR_CHEQUE":
      if (state.cheque === "deposited") {
        patch = { cheque: "cleared", rentPaid: true };
        text =
          "Demo cheque cleared and payment posted once to the sample ledger.";
      }
      break;
    case "SUBMIT_INVOICE":
      if (
        ["completed", "closed"].includes(state.work) &&
        state.vendor === "none"
      ) {
        patch = { vendor: "submitted" };
        text = "Taylor submitted sample invoice INV-104 for JMD 12,500.";
      }
      break;
    case "APPROVE_INVOICE":
      if (state.vendor === "submitted") {
        patch = { vendor: "approved" };
        text = "Finance approved sample invoice INV-104.";
      }
      break;
    case "PAY_INVOICE":
      if (state.vendor === "approved") {
        patch = { vendor: "paid" };
        text = "Sample invoice INV-104 marked paid. No money moved.";
      }
      break;
    case "PAY_TAX":
      if (!state.taxPaid) {
        patch = { taxPaid: true };
        text =
          "Sample property tax obligation marked paid. No government payment was made.";
      }
      break;
  }
  if (!patch) return state;
  return {
    ...state,
    ...patch,
    activity: [{ text, actor: action.actor }, ...state.activity].slice(0, 60),
  };
}
/** Restore only this version and known state values, rather than trusting browser storage. */
export function restoreDemo(raw: string | null): DemoState | null {
  if (!raw) return null;
  try {
    const s = JSON.parse(raw);
    if (s.version !== 1) return null;
    const enums = {
      viewing: ["none", "requested", "confirmed"],
      application: ["none", "submitted", "approved", "signed", "moved_in"],
      seller: ["review", "proposal", "published"],
      work: ["none", "reported", "assigned", "on_site", "completed", "closed"],
      cheque: ["none", "received", "deposited", "cleared"],
      vendor: ["none", "submitted", "approved", "paid"],
    };
    for (const [key, values] of Object.entries(enums))
      if (!values.includes(s[key])) return null;
    for (const key of ["checkedOut", "rentPaid", "taxPaid", "documentReady"])
      if (typeof s[key] !== "boolean") return null;
    if (
      typeof s.issue !== "string" ||
      s.issue.length > 300 ||
      !Array.isArray(s.activity) ||
      s.activity.length > 60 ||
      !s.activity.every(
        (a: { text?: unknown; actor?: unknown }) =>
          typeof a?.text === "string" &&
          a.text.length < 500 &&
          typeof a.actor === "string" &&
          a.actor.length < 100,
      )
    )
      return null;
    return s as DemoState;
  } catch {
    return null;
  }
}
