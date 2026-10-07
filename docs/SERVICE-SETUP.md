# Service setup

The application lives on `foundation/production-v1` in `andremillwood/openhouse-realty`.

## Vercel

Use project `openhouse-realty` (`prj_YmRK1L6UgDsFAcvYLgzEhZSqMUXW`), team `team_9ChwYlVHThc1yEj4aJunzMF6`. Local linkage is stored in ignored `.vercel/project.json`.

The Supabase URL, publishable key, and encrypted Resend key are configured for development, preview, and production. Environment changes apply to subsequent deployments.

## Supabase

Target project: `zikxzkbfxgdilykyyswt`. Use the Supabase plugin account named `open house realty`; the other connection named `Supabase` does not have access. The two foundation migrations were applied through the plugin on October 6, 2026. Local migration filenames match the remote migration history.

The geo/realtor migration was subsequently applied, adding approximate coordinates and two RLS-protected realtor tables. Verified initially: 20 public tables, RLS enabled on all tables, and anonymous listing reads return HTTP 200 with an empty result. Security advisors report informational notices for 10 intentionally restricted internal tables with no client policies. Authenticated ownership policies still need end-to-end verification with test users.

1. Run `supabase login` with the owning account.
2. Run `supabase link --project-ref zikxzkbfxgdilykyyswt` and provide the database password when prompted. Never put the password in source control.
3. Inspect existing remote tables and migration history before applying anything: `supabase migration list`, then `supabase db push --dry-run`.
4. If the existing database is compatible with the migrations, run `supabase db push`.
5. Verify table access as anonymous and authenticated users, and review Supabase security advisors.

The two migrations define 20 tables. Published listings and scheduled open houses are publicly readable; preferences and interactions are scoped to their user. Internal operations and finance tables have RLS enabled and client access revoked pending staff authorization policies. This is a foundation schema, not a completed staff/resident permissions system.

The public marketplace now reads published Supabase inventory; examples are isolated in the demo. Verified account workflows persist saved properties, matching preferences, enquiries, viewing reservations, rental applications and open-house reservations through scoped database/API workflows. Empty live inventory is expected until approved records are published. Signed-in production acceptance remains outstanding.

## Resend

`lib/email.ts` provides a server-only transactional email helper with provider error handling and idempotency keys. `sendEnquiryNotification` routes business notifications to the configured enquiry inbox.

Local and Vercel configuration uses `RESEND_FROM_EMAIL="Open House Realty <notifications@openhousejamaica.com>"` and `ENQUIRY_TO_EMAIL=ohrealty@flashcreate.co`. The recipient is temporary until an official inbox is provided. No email has been sent during setup; the enquiry UI workflow is not yet implemented.

The supplied Resend key is send-only; the domain-list API returned `restricted_api_key`. The user supplied a Resend dashboard screenshot confirming `openhousejamaica.com` is verified for sending.

## Verification

Run `npm ci`, `npm run typecheck`, and `npm run build`. Keep `.env.local` and `.vercel/` ignored. A successful build does not verify remote database access or email delivery.

## Verified accounts

Live routes: `/sign-in`, `/auth/confirm`, `/account`, `/listings`, `/listings/[id]`, `/realtors`, `/staff` and `/staff/enquiries`. `/inventory` redirects to `/listings`. Illustrative walkthroughs live under `/demo`, including `/demo/listings` and `/demo/realtors`.

In Supabase Authentication URL Configuration set the final Site URL and allow the exact callback `<site-origin>/auth/confirm`. For local verification allow `http://127.0.0.1:3001/auth/confirm`. Keep email confirmation enabled. Configure Auth SMTP for production delivery; the Resend enquiry key is not automatically Supabase Auth SMTP configuration. Verify signup and recovery from the deployed origin before launch.

The `staff_accounts` table is not writable by browser users. Verified organization membership authorizes the implemented staff catalog and operational workflows; signup metadata never assigns a staff role. The first administrator must be explicitly approved and have a verified account in the existing approved organization.

Generate reviewable bootstrap SQL with `node scripts/generate-admin-bootstrap.cjs --email approved@example.com --organization APPROVED_ORGANIZATION_UUID > /tmp/openhouse-admin-bootstrap.sql`. Replace both placeholders with approved inputs. The generator does not connect to Supabase or execute SQL. Review the file and execute it through the trusted database administration channel only after checking the exact approved account and organization. The transaction locks the organization and account, requires exactly one matching verified account, and creates only the first administrator. Repeating the same assignment is harmless; existing non-admin roles, other-organization memberships and a different existing administrator require the future audited membership workflow rather than bootstrap. No password, Auth admin key or service credential is needed in this artifact. Preserve the approval and execution record in the operational launch record.

No real first administrator or organization has been provisioned by this tool. Approved email/organization inputs remain outstanding. After bootstrap, verified administrators manage existing accounts at `/staff/memberships`, assigning administrator/realtor/manager/finance roles or revoking access with explicit approval and a reason. Accounts must be verified for assignment; unverified existing members can still be revoked. The workflow rejects cross-organization moves and stale membership revisions, deduplicates identical retries, and prevents demotion/revocation of the last verified administrator. Changes are recorded at `/staff/memberships/history`, with immutable actor/account references and the email snapshot at the change. Baseline bootstrap assignments are not reconstructed into this audit.

Revocation takes effect on subsequent database/application authorization checks. It does not invalidate the person's general Auth session, undo previously committed work, or cancel already in-flight actions. The last-admin guard applies to this controlled workflow; trusted service/SQL operations and Auth user deletion require their own operational review. Email invitations and production signup/recovery delivery remain open work. Resident, contractor, security and owner identities require their separate domain access models; selecting one of these staff roles does not substitute for them.

## Managed work-order intake

Verified organization managers/administrators use `/staff/work-orders` for private queues. Choose a property at `/staff/properties`, then use “Report a property issue” to create a whole-property/common-area or unit ticket. Unit choices and work-order/history pages are bounded to 25 rows. Titles, descriptions and reporting context remain private to authorized management. New tickets start as reported; management can record triage/revise priority or cancel with a reason. Organization, reporter, resource and revisions are derived/checked in the database, with retry IDs and immutable client audit. The current operational creation bound is 30 tickets per actor/database day; cancellation remains available at that bound.

This increment does not provision resident/contractor/security access, dispatch a contractor, notify recipients, certify completion or post charges. These are subsequent parts of the shared maintenance workflow. Property organization and unit parent changes are blocked once work-order history references them. Trusted service/database changes require operational review; direct browser work-order/audit writes are denied.

## Approved contractor register

Verified organization managers/administrators approve contractor identities at `/staff/contractors`. A new registration requires an existing verified Auth email, approved contractor/company name, up to 20 trades, explicit approval and a reason. Each organization has at most one registration per account; the same account may have separate approvals in different organizations. Existing identities cannot be reassigned. Registration edits/deactivation require a current revision and preserve before/after approval history. Unverified accounts cannot be activated, but management can keep them inactive. Direct browser writes and contractor self-approval are denied.

Verified contractors can read their own registration rows, including inactive state, through existing row policies; their account/job portal is still pending the assignment workflow. Internal approval history is management-only. Registration alone grants no work-order, property, unit, resident-document or security-entry access. Work offers, contractor acceptance, scoped job reads, scheduling, evidence and entry authorization remain tracked work. No invitation or notification is sent by registration yet.

## Enquiry notification worker activation

Configure `SUPABASE_SECRET_KEY` server-side in the local ignored `.env.local` and encrypted Vercel environment settings; do not use a `NEXT_PUBLIC_` name or commit it. The connected Supabase plugin exposes publishable keys, not this background credential. Configure a cryptographically random `CRON_SECRET` of at least 32 characters through the same protected settings. Existing Resend sender and recipient configuration applies to the worker.

After credentials and a verified deployment are ready, schedule authenticated GET requests to `/api/jobs/notifications` using `Authorization: Bearer <CRON_SECRET>`. Configure the production scheduler only then. Each job freezes its target title at submission and its sender/recipient on first claim, so later edits cannot change a retry payload. The endpoint claims up to five jobs with exclusive five-minute leases, sends fixed-inbox business notifications using stable provider idempotency keys, and stores provider acceptance. Failures retry with bounded exponential delays; uncertain deliveries older than 23 hours stop for manual review to avoid retries outside the provider’s idempotency window.

`sent` records provider acceptance, not proof that a recipient read or received the email. Delivery/bounce webhook monitoring is still a launch work item. Never manually reset an uncertain job before reconciling provider activity. The SQL verifier `scripts/sql/verify-enquiries.sql` uses transactionally rolled-back fixtures and sends no emails.

Provider retry behavior is based on [Resend’s idempotency documentation](https://resend.com/docs/dashboard/emails/idempotency-keys), which specifies a 24-hour key window.

## Viewing operations

Staff use `/staff/viewings` to enter availability in Jamaica time; the creating staff member is the host. Slots require 15–120 minutes, a start at least 30 minutes in the future, and no overlapping property or host slot. Prospects choose upcoming slots from published property pages and must sign in with a verified email. A request is a temporary hold, not an appointment confirmation. Staff confirmation, cancellation and outcomes are stored and audited.

Viewing notifications share `/api/jobs/notifications`. Prospect recipients come from the verified booking identity; business recipients use the configured enquiry inbox. Messages freeze the property, event time and status. Pending messages for earlier viewing states are superseded; in-flight messages remain historical event notices and link the user back to current account status.

Focused tests: `npm run test:viewings`, `node scripts/verify-viewing-api.cjs`, and rolled-back database fixtures in `scripts/sql/verify-viewings.sql`. These do not send live email.

### Staff enquiry collaboration

Verified organization admin/realtor/manager members use `/staff/enquiries` to assign colleagues, record private follow-up notes, and load notes/assignment history. Directory names come from account display profiles, with role/reference fallbacks when no name is set. Internal notes never enqueue email or appear in prospect history. Assignment conflicts require refreshing the current version; note retry request IDs must retain the same content.

Run `npm run test:staff-enquiries` for API/input boundary regressions. `scripts/sql/verify-enquiry-collaboration.sql` is an administrative BEGIN/ROLLBACK database acceptance check with temporary fixtures; do not run it through a public client.

### Seller reviews

Publish an approved realtor profile with the `sell` service intent before opening seller intake. Sellers choose a realtor for their area and sign in with confirmed email at `/sell`; account history is private. Organization admin/realtor/manager members qualify requests at `/staff/sellers`. Shared follow-up reasons are visible to the seller; do not put internal-only notes in that field. Listing publication requires a separate approved handoff, currently tracked as the next increment.

Seller submission notification snapshots use the existing `ENQUIRY_TO_EMAIL` business inbox and queue worker. Run `npm run test:sellers` and `npm run test:notifications`; the administrative `scripts/sql/verify-sellers.sql` uses BEGIN/ROLLBACK fixtures and sends no email.

### Approved seller handoff

An admin/realtor catalog author records approved public fields and a shared seller-approval reason from the proposal stage at `/staff/sellers`, then opens the generated draft in the catalog editor. Complete approved price/description/photography and optional approximate public coordinates before publishing. Manager access can qualify requests and inspect private history, while catalog authors prepare/publish drafts. Closing a proposal before publication prevents its draft going live.

Use `scripts/sql/verify-seller-handoff.sql` for administrative rolled-back handoff/publication/isolation checks. `npm run test:sellers` includes handoff API boundaries, and `npm run test:catalog` checks positive-price publication.

### Rental application review

Publish an approved rental listing before inviting applications. Verified prospects start from its detail page; current active applications reopen automatically. Organization admin/realtor/manager members use `/staff/applications` and private application detail pages for independent review and shared information/decision reasons. Reviewers cannot act on their own applications. Applicants can reply when information is requested or withdraw before a lease is completed.

Approval, co-signer consent and private document verification are tracked as the next increment. Intake/review does not provision resident access. Every recorded event uses the shared notification worker; applicant notices use the currently verified email, and business notices use `ENQUIRY_TO_EMAIL`.

Run `npm run test:applications` and `npm run test:notifications`; `scripts/sql/verify-applications.sql` is an administrative BEGIN/ROLLBACK test with temporary fixtures and no real sends.

### Private rental application files

Configure server-only `SUPABASE_SECRET_KEY` before enabling uploads; never prefix it with `NEXT_PUBLIC_`. Private document metadata is authorized using the signed-in user's RLS session before any trusted finalization. The `application-documents` bucket accepts PDF/JPEG/PNG up to 8 MiB. Download URLs expire after 120 seconds; upload URLs last two hours. Real Storage upload/download and staff acceptance must be tested with approved verified accounts before launch.

Schedule authenticated GET `/api/jobs/documents` using the existing server-only `CRON_SECRET` (at least 32 characters). It removes at most twenty eligible abandoned/withdrawn files per call, waiting beyond upload-token expiry. Removal failures remain eligible for retry. Choose business retention rules before collecting real documents; completed uploaded files are not automatically purged under an invented policy. Basic signature screening does not establish file authenticity or malware safety.

### Manual application document verification

Start application review before recording a document decision. The document must be finalized and available. Independent verified admin/realtor/manager staff in the application organization can record a reasoned decision from its private detail screen and inspect prior decisions. Staff applicants cannot review their own files or see internal verification notes. A format-checked upload is not automatically verified; staff must check content and source using the business's approved process. Request applicant clarification through the shared application actions, not internal notes. Document decisions alone do not approve an application or activate a lease.

### Co-signer review participation

The applicant creates an invitation from their private application, attesting sharing permission, then shares its private `/cosigners/<id>` link with the intended recipient. New invitations queue recipient email through the shared worker; live delivery requires the configured server credential, scheduler and explicit HTTPS `NEXT_PUBLIC_APP_URL`. The recipient must verify an account matching the invited email; account navigation also shows their accessible invitations. The recipient can accept/decline, then withdraw accepted participation. The applicant can revoke an invitation. Seven-day expiry, two active participants/application and five invitations/day are enforced in the database. Review consent is separate from lease/guarantee signing and does not grant applicant-document access. Verify this flow with separate approved applicant, co-signer, same-organization staff and unrelated accounts before launch.

### Rental approval policy and managed-unit holds

A verified organization administrator records Open House-approved document/co-signer requirements, permitted approver roles and an eligibility-process reference at `/staff/application-policy`. No business policy has been provisioned automatically. Approval requires the current version and an independent authorized reviewer. Complete business checks, reference their evidence internally and write the applicant-facing approval reason. Eligibility evidence for participating co-signers must be checked through that approved process; consent alone is not financial verification.

Published rental listings must have a private property and managed unit link, correct organization and advertised rent matching the application. Unit authoring/linking UI is the next increment. Approval reserves that unit, removes duplicate published listings from availability and creates frozen approval notices. Withdrawals or loss of consent release the hold and pause the listing until catalog staff review publication. Held/converted units cannot be advertised as available or have their listing linkage changed. Approval is lease preparation only; no resident access is activated without the later verified signing/tenancy workflow.

### Private properties, managed units and listing linkage

Use `/staff/properties` with a verified admin/realtor/manager organization account to create a private property, record its exact address and add units. Property and unit revisions guard edits; duplicate unit labels within a property are rejected. Held/converted units and their property details require the later tenancy change workflow. Manager accounts maintain assets; verified admin/realtor catalog authors link listings.

From a selected catalog record, open “Manage private property/unit linkage”, choose the property/unit and save. Choose a unit on the current page (or the existing linked unit); browse other unit pages for more choices. This operation derives and validates the private property relation and preserves an existing seller handoff. It does not copy exact addresses or overwrite public listing facts. Keep approved public facts/maps current in the catalog separately. Linkage and management revisions cannot be written directly by public clients. Private audit history is organization-scoped and paginated. Verify authoring, stale edits, role restrictions and property-to-listing approval with approved real records before launch.

## Register the approved lease template reference

Verified organization administrators can register business-approved template references at `/staff/lease-templates`, linked from the account workspace. Each key has immutable numbered versions, an approved source reference and supplied SHA-256 fingerprint. Request retries are idempotent and stale versions are rejected. Organization scope and actor identity come from verified database membership; client table writes are denied. Other verified staff can read their organization’s registry but cannot register templates.

The fingerprint is supplied by the business. Registration does not upload or independently certify a document and does not send a signing request. No real approved template has been supplied or registered. Lease draft persistence, provider dispatch, verified signature callbacks and resident activation remain pending.

Validation: production build and typecheck passed; focused API checks passed for administrator/origin guards, input bounds, normalized fingerprints, ignored identity spoofing and conflicts. Rolled-back database tests passed for immutable versions, retries, staleness, administrator-only registration and foreign/unverified/prospect isolation. No business records or emails were retained.

## Prepare a lease draft from an approved application

Independent verified admin/realtor/manager staff can open lease preparation from an application review. The `/staff/leases/[applicationId]` workspace uses separately paginated current approved templates and 25-row draft history. The latest draft version is loaded separately so editing an older history page cannot overwrite a newer draft. Staff cannot prepare an application in which they are the applicant or an accepted co-signer.

The audited transaction binds current application approval, the held managed unit, the current version of the selected approved template and verified participant contacts. It derives the rent exactly from the approved application and snapshots the applicant, participating co-signers, managing organization, private address/unit and template source/fingerprint. Deposit money uses exact integer minor units. It does not assume the managing organization is the legal landlord. Legal party details and the actual document remain required for signing.

Draft revisions preserve earlier terms as superseded records, reject stale versions and reuse unchanged request retries. Application approval/participation changes void the prepared draft; co-signer withdrawal also releases the unit through the existing reservation workflow. Direct client draft writes are denied. Prepared drafts and internal terms references are restricted to independent verified organization staff; applicant-facing contract review comes with the signing workflow. Drafts do not sign documents, change approval to leased, activate residents, post charges or send email.

Evidence: production build/typecheck, exact money/date validation, API authorization/origin/body bounds/spoofing/conflict checks and server-page pagination/access/error checks passed. Rolled-back SQL tests proved derived snapshots, retry/mismatch handling, stale application/draft/template rejection, preserved revisions, approved rent stability, changed verified email denial, participant/foreign/unverified isolation, current-template invoker view isolation, and consent-withdrawal invalidation/release. The full approval/reservation regression passed. No actual leases, templates, business records or emails were retained. Security advisors report the same nine informational closed internal tables with no warning/error findings ([reference](https://supabase.com/docs/guides/database/database-linter?lint=0008_rls_enabled_no_policy)).

Signing provider dispatch, actual document certification, legal party details, verified provider callbacks, participant contract acceptance and tenancy activation remain unfinished. Real signed-in staff browser acceptance still requires assigned verified accounts and approved business records. The full production goal remains active.

## Configure co-signer invitation delivery

New permissioned invitations atomically enqueue one limited recipient message. It includes the applicant name, advertised property/area/rent, invitation expiry and private review link; it omits the application message, documents, household and private address. Unchanged invitation retries do not enqueue duplicate messages. Existing invitations are not backfilled or automatically resent.

The shared worker now claims all transactional families through `claim_transactional_notifications`, requires an explicit HTTPS `NEXT_PUBLIC_APP_URL`, and freezes sender, recipient, text and canonical link before the first provider attempt. The existing provider idempotency key and retry/uncertain-delivery limits remain. Older worker calls exclude invitations to avoid sending linkless messages. A service-only preflight validates each current claim before any provider call. Revocation, response or application closure supersedes queued/processing invitation jobs; expiry is checked at claim/preflight. Already-sent/in-flight email cannot be recalled, and invitation links always enforce current verified recipient and application access.

The UI explains that email delivery requires the configured worker and retains direct private sharing. Live delivery remains inactive pending server credential, scheduler, canonical production URL and verified real-account acceptance. No test email was sent.

Evidence: build/typecheck and worker tests passed for canonical URL rejection, authentication, frozen family payloads, stale/revoked attempt skipping, fail-closed preflight, provider failure and uncertain completion. Rolled-back SQL verified one atomic private job, service-only claim/preflight access, legacy-worker exclusion, canonical-link snapshots, stable changed-config retries, revoked lease/completion denial, expiry and application closure suppression. The full co-signer consent regression passed. No actual invitations/business records or emails were retained. Security advisors show the same nine informational closed internal tables and no warnings/errors ([reference](https://supabase.com/docs/guides/database/database-linter?lint=0008_rls_enabled_no_policy)).

Next independent delivery work: organization-scoped notification monitoring and authenticated provider delivery events; open-house publishing/RSVP, legal document/signing, resident operations, finance/native journeys and launch acceptance remain in the full plan.

## Review organization notification status

Verified admin/realtor/manager staff can open `/staff/notifications` from the account workspace. It shows 25-row server pages, state/family filters and organization-wide totals. Each private outbox job gets its organization from the persisted enquiry, viewing, seller, application or co-signer target. Callers cannot supply another organization to the read RPC. A scoped index supports organization lookup; direct client access to the queue remains denied.

The monitor exposes only reference, title, family/audience, queue state, worker-attempt count, timestamps and safe worker error text. Email bodies, recipient addresses, sender, provider IDs and lease tokens remain private. Provider acceptance is explicitly distinct from confirmed delivery/read state. Failed/uncertain jobs are shown for manual review, without automatic resends outside the provider idempotency window. Configuration presence is reported separately from scheduler/delivery acceptance.

Evidence: production build/typecheck, filter/page/authorization/error checks and rolled-back SQL scope/count/pagination tests passed. SQL proved target-derived organization binding despite supplied mismatch, filtered pages beyond 25 rows, organization isolation, payload-field exclusion and anonymous/prospect/unverified denial. Viewing and seller regressions passed after introducing binding for all notification families. No real business records or emails were retained. Security advisors report the same nine informational closed internal tables with no warning/error findings ([reference](https://supabase.com/docs/guides/database/database-linter?lint=0008_rls_enabled_no_policy)).

Authenticated Resend delivery/bounce/complaint events remain the next notification integration work. Live worker/scheduler and staff browser acceptance remain pending server credentials, production configuration and assigned verified accounts. The full production plan remains active.

## Activate verified delivery events

`POST /api/webhooks/resend` verifies the exact bounded request body and Svix headers with the installed Resend SDK before creating a privileged database client. Only configured delivery/sent/delay/bounce/complaint/failure/suppression metadata is accepted. Open/click tracking and unrelated event families are ignored; email bodies, addresses, subject and arbitrary caller organization/outbox fields are not persisted. The endpoint requires server-only `RESEND_WEBHOOK_SECRET`, `RESEND_API_KEY` and `SUPABASE_SECRET_KEY`. It is separate from user-authenticated routes and uses the provider signature as its authority.

Private service-only event records deduplicate the stable webhook ID and reject changed identity/payload hashes. Events arriving before worker completion remain unmatched and are reconciled after the provider message ID is stored; each worker pass runs bounded reconciliation, so a concurrent callback/completion cannot lose the evidence. Provider message IDs are unique per job. Delivery summary preserves complaint/bounce/suppression/failure evidence over positive events and does not regress delivered to delayed/sent when callbacks arrive out of order. The immutable event metadata remains available for trusted reconciliation; event metadata retention is still a business policy input.

Staff monitoring now filters provider outcomes and shows organization-wide outcome totals separately from queue state. Delivery means acceptance by the recipient mail server, without asserting inbox placement or reading. A bounced/complained job remains provider-accepted in the queue; recording delivery evidence never retries or resends it. Staff cannot forge events or read the raw private event store.

Evidence: production build/typecheck, real installed SDK verification against independently generated signatures (raw-byte tampering, wrong key and stale/future timestamps), body bounds, ignored tracking/spoofed/private fields, worker and monitor checks passed. Rolled-back SQL verified early callback retention/reconciliation, replay deduplication/changed replay denial, out-of-order summary preservation, complaint filtering, foreign/unverified isolation and service-only event/reconciliation access. Enquiry/outbox regression passed. Security advisors report ten informational closed internal tables (the new private event store is deliberately service-only) and no warning/error findings ([reference](https://supabase.com/docs/guides/database/database-linter?lint=0008_rls_enabled_no_policy)). No real provider callbacks or emails were exercised, and no fixture records were retained.

Live activation still requires a deployed HTTPS endpoint, Resend webhook registration/signing secret, server credential, worker scheduling and real delivery/replay acceptance. Open-house event publishing/RSVP is the next dependency-ready engineering path; signing/legal inputs, resident activation/operations, finance/native journeys and full launch acceptance remain in the active plan.

Register the final HTTPS site URL followed by `/api/webhooks/resend` in Resend. Subscribe to `email.sent`, `email.delivered`, `email.delivery_delayed`, `email.bounced`, `email.complained`, `email.failed` and `email.suppressed`. Store the endpoint’s signing secret as `RESEND_WEBHOOK_SECRET` in server environment settings and redeploy; do not put it in public/browser variables. Use the [official verification instructions](https://resend.com/docs/webhooks/verify-webhooks-requests) and [event definitions](https://resend.com/docs/webhooks/event-types) for provider setup. Validate a real test delivery/replay after the worker and deployment are configured.

## Schedule an approved open house

Verified admin/realtor/manager staff can schedule an approved event from a published organization listing at `/staff/open-houses`. The host and organization derive from verified membership; private management records hold host identity/version, and immutable author events hold actor/request/reason history. Staff cannot write events/management/audit directly. New event windows are 30 minutes to 120 days ahead, 15 minutes to eight hours long, with an approved title and visitor capacity of 1–250. A daily create limit, optimistic revisions and unchanged request retries guard authoring.

The existing public event policy now hides cancelled/completed/elapsed events and requires a published listing. Same-organization staff can still read their own historical schedule. Cancellation/completion are audited, and completion requires the event end to have elapsed. Time changes use cancellation/new scheduling. Legacy records get organization management bindings with host review required; no arbitrary host was assigned.

Open houses and individual viewing slots share the existing organization scheduling lock. New authoring checks overlapping listing/host slots and events; viewing slot/property and host insertion guards reject the reverse conflicts without leaving orphan slots. Physical-unit overlap across duplicate listing IDs still needs an additional resource guard before this workflow is considered production complete.

The staff workspace separately pages events and published property choices in groups of 25, retains event-state filters and redirects out-of-range pages from counts. A changed property-choice page resets the form retry identity. Public map discovery, RSVP/visitor capacity enforcement, private meeting details, reminders and check-in attribution remain unfinished; the UI states this limitation. No event messaging was enabled in this increment.

Evidence: build/typecheck, input/API/page checks and rolled-back SQL staff/organization/host derivation, request retry, publication attestation, overlap denial in both directions, no orphan slots, completion timing, stale-version handling, cancellation release, public cancellation visibility and foreign/prospect/unverified denial passed. Viewing regression passed. Fixtures were rolled back; no real open houses or emails were retained. Security advisors report the same ten informational closed internal tables and no warning/error findings ([reference](https://supabase.com/docs/guides/database/database-linter?lint=0008_rls_enabled_no_policy)). Signed-in staff/populated browser acceptance remains pending verified assigned accounts and approved records.

Next work: physical-unit scheduling guard, geographic public discovery and RSVP/meeting-detail controls, followed by event notifications/reminders and attendance attribution. The full production goal remains active.

Open-house discovery is available at `/open-houses`; verified attendees manage RSVPs at `/account/open-houses`. Staff author schedules at `/staff/open-houses` using published organization listings. Parties are limited to six, and the database checks event capacity. No RSVP email or reminder currently sends; the transactional worker integration and final worker credentials remain required. Map pins are approved approximate locations; arrival details require team confirmation. Authentication, not a submitted user/org field, determines RSVP ownership.

Staff can approve private event directions from each roster's arrival link. Exact coordinates are optional and require both latitude and longitude. Eligible verified attendees see active instructions on `/account/open-houses` from 24 hours before the event until it ends. RSVP cancellation, event cancellation, publication withdrawal, expiry or staff withdrawal remove database read eligibility. Enter only real business-approved meeting details; no placeholder private addresses are supplied. Arrival notices/reminders are not yet sent.

Open-house emails are now queued for verified RSVP confirmations/updates, eligible 24-hour reminders, cancellations, event availability and arrival changes. They use `/api/jobs/notifications` and the existing Resend signed-delivery webhook. Configure the required server key, 32+ character cron secret, canonical HTTPS production origin and scheduler before expecting sends; current code fails closed when these inputs are absent. Review `open_house` in the staff notification monitor. Email links lead to private account history and omit exact meeting directions. Future reminders are queued only for reservations made more than 24 hours before the event; imminent confirmations cover shorter lead times. Retry snapshots remain fixed to the first worker attempt. No live event email delivery has been claimed.


Contractor offer engine checkpoint: `manage_contractor_work_offer` now supports approved offers and contractor acceptance/decline/release plus management withdrawal. Assignment is distinct from scheduling or entry authorization. The verified `POST /api/work-offers` endpoint is implemented with action-specific validation. Verified contractors have `/account/work-offers` list/detail and response forms, limited to active registrations linked to their account. Managers create/review/withdraw offers from the work-order detail link to `/staff/work-orders/[workOrderId]/offers`; do not treat database availability as completion of the user journey. Rolled-back verification is recorded in the delivery status.

Management offer history is available from work-order detail. The offer list and selected offer audit are scoped to the verified management organization and work order, with 25-record pagination. Internal response and decision reasons are not exposed on contractor account screens.

Visit scheduling database checkpoint: `manage_contractor_visit` supports management proposal, assigned-contractor confirmation/decline and participant cancellation. Schedule changes update work-order/assignment revisions and preserve internal audit. The verified `/api/contractor-visits` API is implemented with action-specific bounds; managers propose/cancel appointments at `/staff/work-orders/[workOrderId]/visits`, and contractors respond from their own offer detail. Inputs and displays use Jamaica time. Entry authorization remains separate; neither assignment nor appointment authorizes access to a property.

Management scheduling links to appointment history across prior assignments. Selected visit history is restricted to the same organization/work order; internal decision reasons remain management-only. Both appointment and change queues use 25-record pagination.

Maintenance windows now coordinate with prospect viewings/RSVPs and mapped listing property/unit calendars. Proposed visits reserve availability as well as confirmed ones. Cancel/decline obsolete proposals to release those reservations. Public inventory must be linked to approved managed property/unit records for physical resource overlap checks. Actual concurrent and signed-in launch acceptance remains pending.

Entry authorization database checkpoint: `manage_entry_permit` records management approval, appointment-bounded shared instructions and internal authority reason. Cancelled appointments revoke permits automatically. Contractors cannot grant/revoke access. The management-only `/api/staff/entry-permits` endpoint is implemented. Management entry forms are available from visit scheduling at `/staff/work-orders/[workOrderId]/entry`; assigned contractors see approved instructions/window on their offer detail. Verified security check-in/out is pending; permit storage alone must not be treated as an entry scan or completed visit. Current permit time/window and appointment/work status must be verified at entry.

Entry decision screens link to the complete management-only permit and change history across prior appointments. Relationship filters restrict records to the selected organization/work order; 25-row queues count before reads. Current permit expiry must still be checked at entry, regardless of its recorded state.

Security assignment database checkpoint: `author_property_security_assignment` approves/deactivates an existing verified account for a specific managed property. These assignments are separate from organization-wide catalog/staff roles and do not expose internal work or resident data. The manager/admin-only `/api/staff/security-assignments` API is implemented with immutable account/property binding. Management property detail links to the security register with approved verified-account creation and activation/deactivation history. Verified entry/check-out is pending; do not treat assignment storage as a live gatehouse workflow.

Presence database checkpoint: `record_contractor_presence` requires current verified property security assignment, a different person from the contractor, explicit identity-check attestation and an in-window current permit/appointment for entry. Exit remains possible after access revocation/expiry, with current property security authority. Gatehouse lookup/screens/API are pending. Departure leaves work in progress for later completion review; it does not mark a job complete.


Property security can now use /security with an exact permit reference. Approved contractors see that reference alongside entry authorization. Only a current verified account assigned to the property can read the gatehouse snapshot or record presence; managers do not receive an implicit gatehouse bypass. The RPC rechecks current permits and appointments when recording arrival. Departure remains available after permit revocation, and does not complete the work order. Signed-in acceptance remains pending.

Presence history is available from the management work-order detail and from a gatehouse permit after arrival has been recorded. Management queries remain scoped to the organization and work order; security queries require current verified coverage for the specific property. Contractor ownership alone does not grant the security event-history screen.


Completion report database workflow now requires an active verified assigned contractor, coherent in-progress work and recorded security departure. Submitted summary/test/outstanding-item text is immutable. An independent organization manager records an explicitly shared review message and either requests changes or approves reviewed work. Approval closes the visit/assignment and revokes entry authorization through existing visit-state guards. The web API/forms and private attachment workflow are not yet connected; no real completion was recorded.

Completion report actions now have a web API at POST /api/completion-reports. Contractor submission and manager review fields are separate; requests use current revisions and stable request IDs. Database-enforced authority/departure requirements still apply. The completion forms and private evidence-upload journey are not yet connected.

Contractors can now open completion reports/feedback from an assignment detail. Management can open completion review from a work-order detail, select a submitted report and request changes or approve. Shared review messages are visibly distinguished from internal decision reasons. Reports remain immutable snapshots; corrections are new submissions after review. Private attachments and signed-in acceptance are pending.


Private contractor evidence database/storage is provisioned in the contractor-evidence bucket. Uploaded files are frozen into completion-report references; referenced files cannot be withdrawn. PDF/JPEG/PNG up to 8 MB are supported, with ten live files per assignment. Trusted-server byte verification requires the still-missing SUPABASE_SECRET_KEY. The evidence API/upload/download screens and expiry cleanup are not yet connected. Metadata-only rolled-back tests passed; actual Storage transfer remains unverified.

Contractor evidence now has a web API at /api/contractor-evidence. Upload reservation and certification remain unavailable until SUPABASE_SECRET_KEY is securely configured; this intentionally prevents creating unfinishable uploads. Downloads use verified account and uploaded-file RLS with 120-second links. Withdrawal does not need a service secret, but submitted-report evidence stays frozen. Browser upload/download screens and live file transfer are pending.

Contractor assignments and completion reports now link to private evidence management. Manager report reviews show only the frozen uploaded files associated with that report. Upload forms remain hidden until the server certification credential is configured. A file transfer is not reported complete until server checks and database certification succeed; interrupted uploads can be retried or finalized from their reservation entry. Actual signed-in Storage acceptance remains pending.

Contractor orphan cleanup is available at /api/jobs/contractor-evidence for a scheduler using CRON_SECRET. It also requires SUPABASE_SECRET_KEY. It waits until reservation expiry plus two hours five minutes, claims up to twenty abandoned/withdrawn files, and never claims uploaded or report-linked evidence. Both secrets remain missing; scheduled execution/live removals are pending. Uploaded evidence retention remains a separate business-policy input.


Maintenance notification processing now runs within the existing authenticated notification job: prepare eligible private events, queue immutable messages, claim leased outbox rows, recheck immediately before sending, record provider acceptance and reconcile signed delivery callbacks. `/staff/notifications?family=maintenance` shows organization-scoped queue/provider outcomes. The worker requires the same server-only Supabase credential, cron secret, Resend configuration and canonical HTTPS app origin as other notifications. Installing the Supabase plugin provides management access but does not supply the deployed server credential. Live operation remains unverified until those settings and scheduler are configured and accepted.

Invoice evidence cleanup is available at `/api/jobs/invoice-evidence`. Configure its authenticated scheduler only after the production deployment and server credentials are verified, using `Authorization: Bearer <CRON_SECRET>` (32+ characters) and server-only `SUPABASE_SECRET_KEY`. Each call claims at most twenty eligible abandoned/withdrawn files with five-minute worker leases. Files wait until reservation expiry plus two hours five minutes, protecting the lifetime of signed upload URLs. Storage removes objects before a service-only RPC records the purge; the RPC rejects still-present objects, wrong/expired claims and current/reviewed evidence. Interrupted jobs become eligible again when their lease expires; a successful marker retry is idempotent. Uploaded/reviewed invoice evidence has no automatic retention policy. Decide its business retention rules separately. Current credentials and scheduled/live execution remain pending.


Staff invitation onboarding: a verified organization administrator creates/revokes approved email-bound roles at `/staff/invitations`, with internal reasons at `/staff/invitations/history`. Recipients sign up or sign in, verify the invited email and review `/account/invitations` before accepting. New invitations atomically queue a recipient notice using the shared `/api/jobs/notifications` worker; no separate Auth-admin invite credential is required. Use the administrator-only `staff_invitation` family in the delivery monitor. Enquiry notices still use the configured business inbox; staff invitation messages retain their approved recipient. Closing/expiry, changed inviting-administrator approval and existing staff memberships suppress pending notices. Invitations cannot overwrite an existing staff role; use the membership register. Seven-day expiry, ten daily creations per administrator and one hundred active invitations per organization are current engineering limits pending business agreement. Live sending still requires the server-only Supabase key, cron secret, canonical HTTPS app origin, Resend settings and verified signed webhook, plus an enabled scheduler. Management plugin OAuth is not a deployed server key. No live invitation email acceptance has been performed.

### Cheque bank evidence and custody

Verified organization administrators and finance staff can record incoming cheque custody at `/staff/finance/cheques`. Bank deposit, clearance and return actions require a current revision, explicit approval, bank reference and a private certified document of the matching purpose. Finish or withdraw active pending uploads before approving a bank decision. A used document remains available for authorized downloads and is retained with its hash, size and bank reference in the audit trail.

Private evidence upload/certification requires a deployed server-side `SUPABASE_SECRET_KEY`; the connected Supabase plugin does not supply this application credential. Configure it only on the server. The private `cheque-bank-evidence` bucket permits PDF, JPEG and PNG up to 8 MB. File format certification does not authenticate the bank document. Deposit and clearance decisions do not initially post ledger entries. A separate finance-approved cleared-cheque posting selects approved chart accounts; an approved return atomically reverses any linked journal. This does not allocate resident balances or replace bank reconciliation. Cleanup is available at `/api/jobs/cheque-evidence`; approved accounting integration remains in development.

Cheque evidence cleanup uses the same server-only `SUPABASE_SECRET_KEY` and authenticated 32-character `CRON_SECRET` as other private evidence jobs. It leases up to twenty expired or withdrawn documents for five minutes, waits until reservation expiry plus two hours five minutes, and excludes all documents retained by bank decisions. Storage removal must succeed before the purge marker is recorded. Wrong or expired claims and still-present Storage objects are rejected. Production scheduling and live execution remain pending deployment credentials.

Lease preparation records retain immutable approved terms and participant snapshots. Service credentials cannot directly insert or update those drafts; preparation and explained closure run through guarded database functions. Preparing a draft does not certify a signature or activate a tenancy. Select the signing provider and supply approved legal templates before live signing acceptance.

Legal template upload cleanup: schedule authenticated GET `/api/jobs/lease-template-documents` using the deployed `CRON_SECRET` and server-only `SUPABASE_SECRET_KEY`. The worker retains certified PDFs, waits beyond signed-upload validity, and uses claim-bound Storage-first removal. Scheduler deployment and actual Storage acceptance are still unverified.

Native registration uses PKCE and `openhouse-realty://auth/confirm`. Add the exact redirect to Supabase Authentication URL Configuration only for the configured Open House mobile application. Verify the mail template respects the requested redirect, email confirmation remains enabled, and confirmation opens the same installed app/device that started registration. Expo Go is not the production scheme acceptance environment. This setup has not been activated or verified with live email/device delivery.

Native password recovery also requires the exact redirect `openhouse-realty://auth/recover`. Verify the installed app handles this route and the emailed recovery redirect preserves the original PKCE flow. Live delivery and device recovery remain unverified.
