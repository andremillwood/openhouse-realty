# Delivery Roadmap

The system is large. Delivery should prove complete vertical workflows rather than build every module shallowly.

## Phase 0 — Foundation

- GitHub/Vercel workflow.
- Dedicated Supabase project.
- Environment management.
- Auth foundation.
- RLS/permissions.
- Domain events.
- Audit strategy.
- Responsive design system.
- Native architecture decision.

## Phase 1 — Marketplace and demand

- Public marketing site.
- Buy/rent inventory.
- Property detail.
- Search.
- For You.
- Preference profile.
- Save/hide.
- Conversational discovery.
- Private tours.
- Open-house listings and RSVP.
- Seller/list-your-property intake.
- Agent/leasing prospect record.
- Resend notifications.

**Proof:** a new prospect can discover a relevant property, understand why it is recommended, book a tour, and appear in the leasing pipeline with attribution.

## Phase 2 — Leasing to resident

- Application.
- Documents.
- Verification.
- Decision.
- Lease.
- Deposit.
- Move-in.
- Household/access.
- Resident account activation.

**Proof:** an applicant can become a resident without information being re-entered across systems.

## Phase 3 — Resident, work orders, and security

- Resident home.
- Service request.
- Work-order generation.
- Contractor assignment.
- Guard expected list.
- Contractor check-in/out.
- Work completion.
- Resident updates.
- Incident management.

**Proof:** a resident issue can travel resident → management → contractor → security → completion with one shared record and no invisible handoff.

## Phase 4 — Finance and collections

- Resident ledger.
- Rent and maintenance invoicing.
- Late fees.
- Payment provider integration.
- Receipts.
- Cheque workflow.
- Reconciliation.
- Vendor invoices.
- Tax obligations.
- Financing-provider offers.

**Proof:** management can explain every balance and reconcile every payment/cheque to the ledger.

## Phase 5 — Native app

Native development can begin earlier in design, but production rollout follows stable domain APIs.

- Expo/React Native app.
- Prospect mode.
- Resident mode.
- Contractor mode.
- Security mode.
- Manager mode.
- Push notifications.
- Camera uploads.
- Deep links.

## Phase 6 — Owner intelligence

- Owner reporting.
- Demand intelligence.
- Service/contractor performance.
- Repair-vs-replace.
- Vacancy/turnover.
- Financial performance.
- Major-decision workflow.

## Scope discipline

Do not build advanced AI, native apps, payment integrations, and the full property back office simultaneously.

First make the underlying workflows and data trustworthy. Intelligence and automation should compound reliable operations, not disguise incomplete ones.
