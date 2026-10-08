# Delivery status

## Implemented and verified

- Git repository checkout and local Vercel project linkage; Supabase and Resend environment configuration.
- Branding: supplied logos, blue/white palette, responsive homepage and navigation.
- Demo listing search, filters, list/map views, approximate map pins, property details, and enquiry email drafts.
- Realtor directory examples and preference-based matching with service eligibility and explained ranking.
- Supabase foundation migrations, approximate coordinate fields, public published realtor profiles, and protected matching-preference tables.
- Stored property/realtor enquiries with atomic rate limits, idempotency, consent and verified-email identity; prospect history and organization-scoped staff inbox with status auditing.
- Server-only Resend notification worker, durable outbox, exclusive leases, retry limits and uncertainty handling. Live email remains disabled until server credentials and scheduling are configured.
- Verified-email account signup/sign-in/recovery, server-validated account access, session refresh proxy, sign-out, and password updates.
- Separate live `/inventory` catalog reading published Supabase rows; authenticated saves stored in `saved_listings` and displayed in `/account`. Empty catalog is explicit; there is no silent demo fallback.
- Administrator-controlled staff membership table, saved-property RLS, profile creation policy, and closed prospect viewing-status escalation.
- Nine-role session-local demo workspace: prospect, realtor, seller, resident, manager, contractor, security, finance, and owner; guided handoffs, sample ledgers, activity, and reset.

The database has foundation tables, not complete operational permissions, entities, or workflows. The homepage, `/listings`, listing details and `/realtors` now read published Supabase data; `/inventory` redirects to `/listings`; illustrative experiences live under `/demo`; the demo workspace is intentionally independent of production data. No real staff role, account, payment processing, document signing, or shared database activity is created by choosing a demo profile.

## Production work in priority order

| Priority | Workstream | Required outcome |
| --- | --- | --- |
| 1 | Identity and access | Sign-in, recovery, invitations, organization membership, role-aware RLS, audited staff permissions and resident/contractor ownership. |
| 1 | Live catalog | Real approved realtor profiles and service styles, verified listings/media, admin publishing, real inventory adapters, persistent saves and preferences, production map service. |
| 1 | Enquiries and viewings | Validated server submissions, abuse prevention, stored prospect records, real Resend delivery and errors, calendar availability, confirmations/cancellations and staff inbox. |
| 2 | Leasing | Application and verification records, secure document storage, decision workflow, legal signing provider, deposit tracking, activation, renewal and move-out. |
| 2 | Operations | Persistent service requests/work orders, assignments, SLAs, evidence uploads, resident notifications, inspections and preventive maintenance. |
| 2 | Security | Identity and job authorization, permitted access windows, check-in/out audit, visitors, deliveries and incident escalation. |
| 3 | Finance | Provider-backed payments, idempotent ledger posting, reconciliation and receipts, cheque returns, vendor approval controls, tax evidence and deposit handling. |
| 3 | Owner intelligence | Metrics derived from verified live events/financial data, portfolio permissions, exceptions, reporting and decisions. |
| 4 | Platform and launch | End-to-end user/permission tests, consent and retention, monitoring, backup/recovery, accessibility, deployment checks and remote client preview. |
| Later | Extended product | Conversational discovery, open-house events/RSVP/check-in, resident communications/amenities/household flows, approved financing providers, native mobile apps and push. |

## First production milestone

Deliver one real path: authenticated prospect → published property → stored enquiry → confirmed viewing → staff pipeline, with an actual verified email and correct cross-user permissions. Then extend the same identities and records through application and resident activation. Demo screens provide a concrete review target for those workflows, not evidence they are already production-ready.

## October 6 production increment

Typecheck, production build, and demo lifecycle checks passed. Browser checks cover anonymous account redirection and live inventory rendering. Transactional database fixtures verified cross-user saved-property isolation, draft invisibility, forbidden self-appointment as staff, and forbidden prospect confirmation; fixtures were rolled back.

No verified real account exists yet, so signup-email delivery, recovery-email delivery, and authenticated browser persistence have not been verified end to end. The account infrastructure and save functionality are implemented; the complete first production milestone is still open.

Before enabling production accounts: configure Supabase Site URL and allowed redirect URLs for the final deployment origin plus `/auth/confirm`, confirm email confirmation is enabled, configure production Auth SMTP and password/rate-limit settings, verify mail delivery, create and verify the nominated administrator account, and provision its staff membership through a privileged administration channel. Demo role selection never provisions staff access.

Next implementation: staff publishing with approved media/location fields and organization-scoped access; stored, rate-limited enquiries and a durable email outbox with retries; staff inbox, viewing availability, and state transitions. Current Resend helper alone is not an enquiry workflow. Deployment remains pending until these checks and content approval are complete.

## Full-plan execution

See `PRODUCTION-DEVELOPMENT-PLAN.md` for the dependency-ordered checklist and definition of finished. The execution goal remains active. Staff catalog authoring now includes listing/realtor editor screens, server-side validation and organization-scoped database policies. Own-organization visibility, cross-organization insert denial, ownership transfer denial and incomplete publication denial passed using rolled-back fixtures. Live catalog now includes search, area/intent filters and approved approximate map views. No staff account has been provisioned, and no real listing has been published.

## Live discovery and demand increment

The public homepage now uses approved inventory and honest empty states. `/listings` includes intent/area/text discovery and approved approximate list/map views. `/listings/[id]` reads published records only, with saved-property controls and stored enquiries. `/realtors` uses approved profiles, eligibility-filtered explainable ranking, explicit preference-save consent and stored introduction enquiries. Original experiences remain at `/demo/marketplace`, `/demo/listings` and `/demo/realtors`.

New enquiry records derive contact email and organization from verified identity and the published target. The database enforces consent, five enquiries/hour and twenty/day, per-user idempotency, private prospect history, and organization-scoped staff access. Staff status changes produce immutable history. A notification is enqueued in the same transaction; provider failures do not lose the enquiry.

Verification: build/typecheck; catalog, discovery, enquiry input and notification worker unit checks; rolled-back database tests for enquiry identity/consent/rate limits/idempotency/isolation, staff audit and exclusive worker leases; public/anonymous browser checks. Browser testing found and corrected a request-origin hostname mismatch affecting sign-out and mutations. Live accepted/delivered email, verified staff/prospect browser submissions and full viewing management are still unverified/pending. No real enquiry or email was created by these tests.

Next dependency-ready work: staff viewing availability and request/confirmation/cancellation workflow; public catalog pagination and demand attribution; seller intake and staff lead ownership/notes. Background notifications require `SUPABASE_SECRET_KEY` and `CRON_SECRET`, both currently absent locally, plus a production schedule and delivery monitoring.

Notification payload follow-up: titles are frozen when enquiries are submitted; sender/recipient are frozen on first worker claim. This protects retries from catalog and inbox edits. Database tests confirmed the frozen title survives a later property edit.

## Viewing workflow increment

`/staff/viewings` manages property availability and staff-hosted slots; published property pages expose public upcoming times. Verified prospects request a temporary hold, track it in `/account`, and can cancel future active appointments. Authorized organization staff confirm, cancel and resolve completed/no-show appointments. The database serializes request capacity and protects active slot uniqueness, property/host calendars and prospect overlap. Requested holds expire after at most 24 hours or 15 minutes before the appointment; stale holds are safely resolved during reuse or staff/owner actions.

Public slots contain no prospect identity, exact address or host identity. Hosts live in a private table. Booking event history is immutable to browser users. Expiry events omit the identity of a later requester. Each meaningful booking transition creates frozen prospect/business notification payloads; obsolete pending notifications are superseded. Provider acceptance still depends on worker configuration.

Evidence: production build/typecheck; viewing input/timezone validation, mocked API guards and conflict/error handling; rolled-back database tests for slot/request idempotency, property/host/prospect conflicts, unique capacity, public availability, cross-user/cross-organization isolation, staff-only confirmation, cancellation/release, hold expiry, audit events and safe queued messages. These are focused checks, not a real-client end-to-end signoff or a production load test. No fixture records or emails were retained.

Pending for this milestone: administrator provisioning, approved listings and real staff/prospect browser acceptance; live notification delivery; staff calendar/availability audit expansion and calendar-provider synchronization if required by the business. The overall goal remains active.

## Catalogue pagination increment

Public listing search, intent and area filters now apply before pagination in Supabase. Each page loads at most 24 published properties with a deterministic publication/id order and an exact matching count. Previous/next links preserve filters; out-of-range pages redirect to the last valid page. Repeated/malformed URL parameters are normalized; search text strips PostgREST grammar and wildcard characters. Area uses text search across all published inventory rather than a dropdown drawn only from the current page. Saved-state lookup is restricted to page listing IDs.

The map explicitly covers the current page, with unmapped properties retained in its list. This is paged list/map discovery; map viewport search and cross-page geographic aggregation remain future enhancements. Input/navigation boundary checks, mocked server-page regressions, typecheck and production build passed. Runtime requests against the live empty inventory confirmed preserved filter values and out-of-range canonicalization. That check caught a Supabase range error; the final implementation counts matches before fetching rows, and the corrected runtime check passed. Populated-inventory browser acceptance still needs approved real inventory.

## Staff enquiry collaboration increment

The organization inbox supports colleague assignment/unassignment and private follow-up notes. Internal records live in separate RLS-protected tables, so prospect enquiry history cannot expose staff notes or assignment metadata. The restricted colleague directory returns only verified admin/realtor/manager members of the current organization; staff email addresses are not exposed by that directory. All assignment changes produce immutable events. Notes are immutable and use per-author request IDs for retry safety, with a 200-note rolling-day bound.

Assignments serialize on the enquiry and use optimistic versions. A stale conflicting change returns HTTP 409; exact retries of the previous successful assignment do not duplicate audit history. Private notes and assignment history load on demand in 25-item pages. Staff reads additionally require confirmed email directly in database policy checks. Status updates refresh from server props rather than keeping a stale client copy.

Evidence: focused input/API tests, typecheck, production build, rolled-back database tests for same/foreign-organization access, prospect privacy, finance/unverified exclusions, restricted directory, assignment retry/conflict/unassignment audit, immutable notes and request-ID payload conflicts. No test fixtures or real notifications were retained. Security advisors report only the previously recorded informational policy-free internal tables.

Remaining demand work: paginate/filter the staff inbox across all enquiries (the current inbox loads the most recent 100), seller intake, attribution and enquiry-to-application handoff. The main preview was refreshed; anonymous inbox navigation redirects to sign-in and the history API returns 401 without records. Real verified staff browser acceptance remains pending account provisioning.

## Full staff inbox increment

The staff inbox now loads 25-row pages across all organization enquiries. Status filters apply in the database before matching totals and pagination. Count queries run before range queries so empty/stale high pages redirect safely. Previous/next links preserve the selected status; stable creation/id ordering prevents ambiguous ties. Assignments load only for the current page, while the colleague directory loads alongside the count. This replaces the earlier 100-record cap and page-local status filtering.

Focused server-page checks prove organization/status filters on count and row queries, page-five range access beyond record 100, malformed/repeated URL normalization, empty/out-of-range redirects, unavailable-count handling, and no database queries for unauthorized visitors. Typecheck and production build passed; collaboration API regressions also passed after the inbox changes. The main local preview was refreshed. Real staff/browser acceptance across populated data remains pending a verified assigned staff account. Assignment-specific inbox filters are still a useful follow-up; current filtering is by status.

## Verified seller intake and qualification increment

`/sell` starts a private property-review request through a published realtor offering sell services. Visitors sign in before entering private details. Submission derives contact email and organization from verified identity and the approved realtor, strips supplied identity/routing/status fields, requires explicit consent, and enforces idempotency plus three requests per rolling day. The former unrestricted anonymous seller-lead insert grant/policy is retired. Legacy unrouted records are preserved for administrative review. Exact property addresses are readable only by the owner or verified authorized organization staff; they never become public map/listing data automatically.

Submission, initial history and a frozen business notification payload commit together. The existing queue worker handles seller snapshots with the same lease/retry/idempotency controls. `/account` shows private requests and shared follow-up history. `/staff/sellers` has organization-scoped 25-row pages/status filters and audited contact → property review → proposal → closure/not-proceeding stages with shared reasons. Stale transitions conflict; direct client writes, stage skipping, unapproved listed status and terminal reopening are rejected. Seller qualification does not yet create a property/listing; publication handoff is the next increment.

Evidence: seller input/API boundaries and trusted RPC argument tests; notification worker snapshot tests; production build/typecheck; rolled-back database checks for verified identity, consent, target eligibility, rate limits, duplicate/reused request IDs, private address/history isolation, foreign staff denial, review/stale-state/audit gates, anonymous-write retirement and three frozen business jobs claimed by the worker. Enquiry/viewing database regressions passed after expanding the outbox entity constraint. Security advisors retain only the previously documented informational policy-free internal tables ([Supabase advisory reference](https://supabase.com/docs/guides/database/database-linter?lint=0008_rls_enabled_no_policy)). No fixtures or real emails were retained.

The rebuilt local preview returns the honest empty sales-team state, denies anonymous seller POSTs with 401, and redirects anonymous staff to sign-in. Mobile browser checks show the branded seller page without horizontal overflow. Real form/staff browser acceptance needs an approved sales roster and verified assigned accounts; real email sending needs the protected worker credentials/schedule. The overall goal remains active.

## Seller proposal-to-listing handoff increment

Authorized verified catalog authors can attest seller proposal approval and prepare a property/listing draft from `/staff/sellers`. The transaction creates one private property, one sale draft, an immutable handoff record and shared seller history. The exact address is retained in the private property; only explicitly approved public title/area/type are copied into the draft, with blank description/photo/coordinates and zero draft price. Retrying the same request/content returns the same records; a second handoff conflicts. Seller authorization is recorded as a staff attestation; any agency agreement remains with the business’s approved process.

The staff catalogue now opens a requested draft directly via `/staff?listing=<uuid>` with organization filtering and preselection, including records outside the normal 200-row authoring batch. Publication requires existing approved content/photography checks and a positive advertised price, then atomically advances the seller to Listed and records one publication event. Pausing/re-publishing does not duplicate that event. An inactive/withdrawn proposal cannot publish its prepared draft. Account history links to the public listing only while it is available.

Private properties/units have verified organization-staff read policies. Prospects retain private request access without receiving internal property/unit/handoff permissions. Database triggers reject cross-organization property relations, units belonging to a different property, and reassignment of a seller handoff to another property. Direct catalogue listing/realtor writes now require verified admin/realtor membership in their own organization.

Evidence: production build/typecheck; seller API handoff approval/type/spoofing/conflict checks and catalog positive-price boundaries; rolled-back database verification covering proposal/consent prerequisites, immutable linkage, same-record retries, private/public separation, manager/foreign/unverified restrictions, foreign/unrelated property and unit rejection, content/zero-price publication denial, withdrawn proposal denial, seller history and single listed audit event. Existing seller intake, viewing and enquiry database regressions passed with the new policies/guards. No fixtures or real emails were retained. Security advisors now report nine informational closed internal tables ([reference](https://supabase.com/docs/guides/database/database-linter?lint=0008_rls_enabled_no_policy)); no warning/error findings.

The main local preview was refreshed; anonymous direct-draft navigation redirects to sign-in and the handoff API returns 401 without creating records. Real approved-content staff/seller browser acceptance is still pending verified assigned accounts. Private property editing/unit authoring, rental applications and documents, open-house events, invitation provisioning and observable email delivery remain in the active plan. This increment does not complete production readiness.

## Rental application intake and review increment

Published rental details link to `/apply/<listing-id>`. Verified prospects submit household size, preferred move-in, contact name/phone, a message and explicit review consent. The database derives email and organization, freezes advertised rent/title/area, validates optional enquiry ownership/target, restricts new requests to published rental inventory and dates within the next year, allows one active application per applicant/listing, and caps five submissions/day plus three active applications. A request UUID preserves retry safety. Catalog changes do not alter the submission quote.

Private `/applications/<id>` shows shared review history and applicant/staff actions. `/staff/applications` has organization-scoped 25-row status-filtered pages. Independent verified staff can start review, request clarification and record a reasoned decision not to proceed; applicants reply/resubmit or withdraw. Staff cannot review their own application or impersonate applicant replies. Events/version checks prevent duplicate retries and stale overwrites; direct client table writes and premature approval/lease actions are denied. Supporting document verification, co-signers and approval are the next increment; no tenancy can be activated from this intake/review UI.

Each event atomically queues frozen applicant/business notices, derives the applicant recipient from their currently verified email and supersedes older pending application notices. The generic worker claims these jobs using its existing lease/retry/idempotency contract. Provider acceptance/delivery still needs the protected worker credentials and live verification.

Evidence: production build/typecheck; input/API checks for calendar/household/consent/UUID bounds, Jamaica date handling, ignored identity/quote/status spoofing, origin/verified-auth guards and RPC conflict/permission responses; rolled-back database tests for published rental eligibility, enquiry ownership, frozen quotes, idempotency/active uniqueness/rate limits, private histories, foreign/unverified staff denial, independent review, applicant replies, rejection/withdrawal audit, terminal states and premature approval denial. The worker claimed all sixteen current fixture application notices with correct recipients and snapshots; all fixtures/claims were rolled back and no email sent. Existing enquiry/viewing/seller regressions passed after expanding the outbox. Security advisors retain nine informational closed internal tables ([reference](https://supabase.com/docs/guides/database/database-linter?lint=0008_rls_enabled_no_policy)); no warning/error findings.

The refreshed local preview redirects anonymous apply/detail/staff routes to sign-in and rejects anonymous submissions with 401. Actual signed-in applicant/staff browser acceptance across approved inventory remains pending verified assigned accounts. The overall goal remains active.

## Private application document increment

Application detail now presents private identity/income/reference/other document uploads (PDF/JPEG/PNG, 8 MiB, ten active documents). A verified owner reserves an opaque application/document path; Storage denies overwrite and direct client deletion. Uploaded files remain unavailable to staff until the server retrieves the actual bytes, checks basic format/size and records a SHA-256 fingerprint through a service-only function. Clients cannot certify metadata. Verified staff in the same organization can download finalized files through two-minute attachment links. Owners can withdraw documents while application review remains active; existing signed download links may last up to two minutes.

Private bucket/RLS and immutable document events are applied to Supabase. Cleanup removes expired reservations and withdrawn objects only after the latest possible two-hour upload token has expired, with a five-minute buffer. The protected `/api/jobs/documents` endpoint processes twenty eligible records and retries failed removal/metadata updates. Uploaded documents in completed applications are retained until a business retention policy is supplied. Format screening is not malware scanning or authenticity verification, and approval remains unavailable.

Evidence: typecheck, focused API/file-format tests and rolled-back SQL tests passed. Checks cover owner/staff/foreign organization access, unfinished-file staff denial, direct metadata/finalization denial, same-request reservation/finalization retries, withdrawal access revocation, token-safe cleanup timing and audit deduplication. No real application files or emails were submitted. Full Storage transport, signed-in browser acceptance and cleanup execution still require a server Supabase credential, verified test accounts and scheduling. Upload UI/API stays unavailable while the server credential is absent.

## Staff document verification increment

Independent verified organization staff can review finalized application documents while the application is under review. Decisions are Verified, Clarification needed, or Not accepted, with an internal reason, reviewer identity, exact file fingerprint, optimistic review version and immutable audit. Identical retries return the current result without duplicating history; changed retries and stale reviews conflict. Direct metadata writes, self-review (including staff applicants), foreign-organization and unverified staff access are denied. Withdrawn/unfinished files cannot receive new decisions.

The private application document panel presents current decisions, a category checklist and lazily fetched 25-row decision history. Applicants cannot read internal reasons; staff use the existing shared information-request flow to communicate actionable clarification. No internal notes are copied into applicant emails. Verification records persist after withdrawal for staff audit, while withdrawn files disappear from the current checklist. Application approval remains unavailable pending co-signer consent, eligibility/property checks and approval implementation.

Evidence: focused API/input tests and rolled-back SQL tests passed for version/decision bounds, ignored reviewer/organization/hash spoofing, verified identity/origin guards, RLS-authorized lazy history, permission/status mapping, fingerprint binding, retry deduplication, stale-update rejection, direct-write denial, independent reviewer access and withdrawn-file rejection. Existing document and cleanup tests passed. Security advisors report only the same nine informational closed internal tables, with no warning/error findings ([reference](https://supabase.com/docs/guides/database/database-linter?lint=0008_rls_enabled_no_policy)). Real signed-in staff/file acceptance remains dependent on approved accounts and the upload server credential.

The final production build and typecheck passed with the category checklist and lazy history. The refreshed local preview denies anonymous document-review GET/POST requests with 401. This is runtime guard evidence, not authenticated browser acceptance. The broader production goal remains active.

## Co-signer review-consent increment

Verified applicants create a private co-signer invitation after attesting permission to share their name and frozen property title/area/advertised rent. Invitations expire after seven days, allow at most two pending/accepted participants per application and five creations per applicant/day, and preserve request retries. Applicants cannot invite themselves or mark recipient consent. Expired pending invitations are revoked with an audit when replaced. The application shows active invitations independently of the recent 25-record history, so old accepted participants do not disappear behind newer records.

Invited recipients sign in through their own verified matching email, see only the limited invitation snapshot, and explicitly accept or decline review participation. Accepted/declined records bind to their account ID; email changes do not allow another account to take over consent. An accepted recipient can withdraw consent, and the applicant can revoke an invitation. Versioned events prevent stale updates and duplicate retries. Application versions advance with changes; removing consent from an approved fixture reopens review. No consent here signs a legal guarantee, and applicant documents/internal review notes remain inaccessible to recipients. `/cosigners/<id>` includes private paginated decision history and checks application availability before offering actions; recipient invitations appear in their account.

The first migration attempt was rejected by automatic approval review over potential audit disclosure. The audit policy was rewritten with explicit applicant, bound/invited verified recipient and organization-staff predicates; the revised migration passed approval review. Rolled-back database tests then proved foreign/unverified exclusion, recipient-only limited reads, inability to impersonate or directly update consent, sharing/consent prerequisites, active/daily limits, expiry replacement audit, retries, stale denial, decline/withdrawal, account binding after email change and approval invalidation. Focused API tests passed for bounds, ignored identity/status spoofing, verified-origin guards and permission/conflict/rate responses. No real invitations, emails or fixture accounts were retained. Security advisors remain at nine informational closed internal tables and no warning/error findings ([reference](https://supabase.com/docs/guides/database/database-linter?lint=0008_rls_enabled_no_policy)).

Invitation delivery currently uses a private link shared by the applicant; the UI explicitly states that automated email delivery is not active. Outbox-backed invitation delivery, co-signer evidence verification, application-level eligibility/property approval, real multi-account browser acceptance and lease signing remain tracked work. This increment does not complete application approval or production readiness.

Final typecheck and production build passed. The refreshed local preview redirects an anonymous private invitation request to sign-in and returns 401 for anonymous co-signer mutation requests. These runtime checks do not replace the pending real multi-account consent walkthrough. The production goal remains active.

## Business-policy application approval increment

Verified organization administrators can record approved business requirements in `/staff/application-policy`: required document categories, zero-to-two consenting co-signers, permitted approver roles and an approved eligibility-process reference. No actual organization policy is preconfigured. Versions are append-only, retry-safe and optimistic; approval locks the current policy against concurrent configuration changes. The policy editor requires explicit business approval attestation.

Independent reviewers authorized by the policy can approve an application under review after completing eligibility/availability attestations and recording an internal evidence reference plus a shared decision reason. The database requires current application/policy versions, a current move-in date, verified required documents tied to their actual fingerprints, no open uploaded-file issues, completed required co-signer consent, no unanswered active invitations, matching advertised rent and a published rental listing linked to a real managed unit in the same organization. Applicants and participating co-signers cannot approve their own involvement. Required document reviews by a participating co-signer do not satisfy independent verification.

Approval freezes document review fingerprints/versions, co-signer consent and the business-policy reference in a private immutable decision record, creates one unique active hold per unit, changes the selected listing to Under offer, pauses published duplicate listings for that unit, advances application history/version and enqueues frozen applicant/business approval notices through the existing worker. Retrying returns the current state without reapproving a withdrawn application. Reserved listings cannot change property/unit/organization bindings or be advertised as available; duplicate listings for held/converted units cannot be republished. Removal of approval through withdrawal or co-signer consent loss releases the held unit, pauses its listing and supersedes pending approval notices. Staff review publication before making it available again.

Evidence: focused API/input tests and rolled-back database tests passed for policy prerequisites, admin-only configuration, allowed requirements/role boundaries, policy retries/staleness, unverified evidence/missing co-signer denial, independent/foreign restrictions, current terms/unit prerequisites, atomic approval, frozen evidence, shared notices, reservation uniqueness, unavailable duplicate-listing rejection, immutable reserved binding, publication denial, consent-loss release, safe withdrawal after catalog content edits, stale-notice suppression and reuse after release. The tests use rolled-back fixture approvals; no business policy, approvals, emails or resident accounts were retained.

Approval does not sign a lease or create tenancy access. Real policy approval, property/unit authoring/linkage, verified staff/prospect/co-signer browser acceptance and notification worker activation remain pending. Co-signer financial/source evidence is currently attested via the approved external eligibility reference; a dedicated evidence-collection experience and automated invitation delivery remain tracked follow-ups. The overall production goal stays active.

Additional database evidence confirms the active-unit unique index itself rejects a second held reservation, a participating co-signer with staff privileges cannot approve, changed price/unbound managed units are rejected, and actual consent withdrawal releases a real fixture reservation. Existing co-signer lifecycle regression also passed with the new release trigger. Security advisors report the same nine informational closed internal tables and no warning/error findings ([reference](https://supabase.com/docs/guides/database/database-linter?lint=0008_rls_enabled_no_policy)).

The final typecheck/build passed. In the refreshed local preview, the private policy page redirects anonymous users to sign-in and the approval API returns 401 without creating records. Actual business policy/unit setup and authenticated browser acceptance remain pending; no real policy was approved by the development tests.

## Private managed inventory authoring increment

Verified admin/realtor/manager staff can create and edit private properties and units at `/staff/properties`. Property records hold the exact address; unit records hold labels and physical facts. Revision checks and request UUIDs prevent stale overwrites and duplicate retries. Units cannot change their property through this editor. Property/unit ownership is derived and checked in the database; clients cannot write these tables directly or inject organization/actor fields into the audited RPC.

Catalog authors can open a selected listing’s private management workspace, choose a property and managed unit, or explicitly remove its unit link. The operation derives the property from the unit and preserves seller-handoff property bindings. Public facts/approximate coordinates are edited separately; exact addresses and private inventory audit are never copied into public listings. Column grants now prevent direct public-client listing property/unit/revision writes, so linkage goes through the audited operation. Managers maintain assets but cannot author listing linkage.

Properties, units and audit use separate 25-row server pages with count-first out-of-range redirects. Direct property/listing references work outside a displayed page, and the current linked unit stays selectable when it is outside the current unit page. Current and historical private changes are visible to verified same-organization staff only. Held/converted units and their property details cannot be edited through this workflow; listing reservation protections and seller-handoff immutability remain enforced. Managed authoring and approvals share an organization lock to avoid conflicting unit/duplicate-listing operations.

Evidence: typecheck and production build; focused API bounds/authorization/spoofing/conflict tests; rolled-back SQL property/unit create/edit/retry/staleness, unique labels, dimension bounds, manager-versus-catalog roles, direct-write/linkage bypass denial, foreign/prospect/unverified read isolation and audit checks passed. Approval regression proved reserved property/unit/linkage changes are denied. Seller-handoff regression proved unrelated/foreign managed units remain denied and a valid unit can be attached within the handed-off property. Its older direct-write assertions were updated to recognize the stronger column-permission denial; the intended isolation assertion remains. Catalog boundary tests also passed. No real properties, units, approvals or emails were retained.

Security advisors report only the same nine informational closed internal tables, with no warning/error findings ([reference](https://supabase.com/docs/guides/database/database-linter?lint=0008_rls_enabled_no_policy)). Real staff-browser editing, populated pagination and approved inventory acceptance remain pending verified assigned accounts and business content. Lease preparation/signing and resident activation are the next dependency-ready work item; payments, event publishing, operations, invitation delivery and launch acceptance remain in the full active plan.

The final build/typecheck passed after current-link error handling. The refreshed local preview redirects anonymous private-inventory navigation to sign-in and denies anonymous managed-inventory POSTs with 401. These checks prove runtime guards; signed-in populated browser acceptance remains pending approved accounts and content.

## Lease preparation validation foundation (in progress)

Lease term parsing now validates real ordered dates using the Jamaica date boundary, application/approved-template versions, monthly billing day, approved-term attestation and an internal reference. Deposit amounts convert to exact decimal minor units using BigInt, avoiding floating-point rounding. Caller-supplied rent, applicant/organization/unit, signers and signed status are excluded; the forthcoming transaction must derive those from approved records. Focused boundary tests and typecheck passed. This library is not yet wired to a persistence/API/UI workflow. Approved template registration, lease draft snapshots, provider dispatch, verified webhook handling and resident activation remain unfinished; no lease or signing request was created.

## Approved lease template registry

Verified organization administrators can register business-approved template references at `/staff/lease-templates`, linked from the account workspace. Each key has immutable numbered versions, an approved source reference and supplied SHA-256 fingerprint. Request retries are idempotent and stale versions are rejected. Organization scope and actor identity come from verified database membership; client table writes are denied. Other verified staff can read their organization’s registry but cannot register templates.

The fingerprint is supplied by the business. Registration does not upload or independently certify a document and does not send a signing request. No real approved template has been supplied or registered. Lease draft persistence, provider dispatch, verified signature callbacks and resident activation remain pending.

Validation: production build and typecheck passed; focused API checks passed for administrator/origin guards, input bounds, normalized fingerprints, ignored identity spoofing and conflicts. Rolled-back database tests passed for immutable versions, retries, staleness, administrator-only registration and foreign/unverified/prospect isolation. No business records or emails were retained.

## Persisted lease draft preparation

Independent verified admin/realtor/manager staff can open lease preparation from an application review. The `/staff/leases/[applicationId]` workspace uses separately paginated current approved templates and 25-row draft history. The latest draft version is loaded separately so editing an older history page cannot overwrite a newer draft. Staff cannot prepare an application in which they are the applicant or an accepted co-signer.

The audited transaction binds current application approval, the held managed unit, the current version of the selected approved template and verified participant contacts. It derives the rent exactly from the approved application and snapshots the applicant, participating co-signers, managing organization, private address/unit and template source/fingerprint. Deposit money uses exact integer minor units. It does not assume the managing organization is the legal landlord. Legal party details and the actual document remain required for signing.

Draft revisions preserve earlier terms as superseded records, reject stale versions and reuse unchanged request retries. Application approval/participation changes void the prepared draft; co-signer withdrawal also releases the unit through the existing reservation workflow. Direct client draft writes are denied. Prepared drafts and internal terms references are restricted to independent verified organization staff; applicant-facing contract review comes with the signing workflow. Drafts do not sign documents, change approval to leased, activate residents, post charges or send email.

Evidence: production build/typecheck, exact money/date validation, API authorization/origin/body bounds/spoofing/conflict checks and server-page pagination/access/error checks passed. Rolled-back SQL tests proved derived snapshots, retry/mismatch handling, stale application/draft/template rejection, preserved revisions, approved rent stability, changed verified email denial, participant/foreign/unverified isolation, current-template invoker view isolation, and consent-withdrawal invalidation/release. The full approval/reservation regression passed. No actual leases, templates, business records or emails were retained. Security advisors report the same nine informational closed internal tables with no warning/error findings ([reference](https://supabase.com/docs/guides/database/database-linter?lint=0008_rls_enabled_no_policy)).

Signing provider dispatch, actual document certification, legal party details, verified provider callbacks, participant contract acceptance and tenancy activation remain unfinished. Real signed-in staff browser acceptance still requires assigned verified accounts and approved business records. The full production goal remains active.

The refreshed preview redirects anonymous template and lease-preparation pages to sign-in, denies anonymous lease-draft POSTs with 401, and returns private/no-store cache headers. Runtime guards passed; authenticated business walkthroughs remain pending.

## Co-signer invitation email queue

New permissioned invitations atomically enqueue one limited recipient message. It includes the applicant name, advertised property/area/rent, invitation expiry and private review link; it omits the application message, documents, household and private address. Unchanged invitation retries do not enqueue duplicate messages. Existing invitations are not backfilled or automatically resent.

The shared worker now claims all transactional families through `claim_transactional_notifications`, requires an explicit HTTPS `NEXT_PUBLIC_APP_URL`, and freezes sender, recipient, text and canonical link before the first provider attempt. The existing provider idempotency key and retry/uncertain-delivery limits remain. Older worker calls exclude invitations to avoid sending linkless messages. A service-only preflight validates each current claim before any provider call. Revocation, response or application closure supersedes queued/processing invitation jobs; expiry is checked at claim/preflight. Already-sent/in-flight email cannot be recalled, and invitation links always enforce current verified recipient and application access.

The UI explains that email delivery requires the configured worker and retains direct private sharing. Live delivery remains inactive pending server credential, scheduler, canonical production URL and verified real-account acceptance. No test email was sent.

Evidence: build/typecheck and worker tests passed for canonical URL rejection, authentication, frozen family payloads, stale/revoked attempt skipping, fail-closed preflight, provider failure and uncertain completion. Rolled-back SQL verified one atomic private job, service-only claim/preflight access, legacy-worker exclusion, canonical-link snapshots, stable changed-config retries, revoked lease/completion denial, expiry and application closure suppression. The full co-signer consent regression passed. No actual invitations/business records or emails were retained. Security advisors show the same nine informational closed internal tables and no warnings/errors ([reference](https://supabase.com/docs/guides/database/database-linter?lint=0008_rls_enabled_no_policy)).

Next independent delivery work: organization-scoped notification monitoring and authenticated provider delivery events; open-house publishing/RSVP, legal document/signing, resident operations, finance/native journeys and launch acceptance remain in the full plan.

The refreshed local preview denies anonymous notification-worker requests with 401. Provider calls were not exercised against Resend; mocked provider and rolled-back database evidence are recorded above.

## Organization notification monitor

Verified admin/realtor/manager staff can open `/staff/notifications` from the account workspace. It shows 25-row server pages, state/family filters and organization-wide totals. Each private outbox job gets its organization from the persisted enquiry, viewing, seller, application or co-signer target. Callers cannot supply another organization to the read RPC. A scoped index supports organization lookup; direct client access to the queue remains denied.

The monitor exposes only reference, title, family/audience, queue state, worker-attempt count, timestamps and safe worker error text. Email bodies, recipient addresses, sender, provider IDs and lease tokens remain private. Provider acceptance is explicitly distinct from confirmed delivery/read state. Failed/uncertain jobs are shown for manual review, without automatic resends outside the provider idempotency window. Configuration presence is reported separately from scheduler/delivery acceptance.

Evidence: production build/typecheck, filter/page/authorization/error checks and rolled-back SQL scope/count/pagination tests passed. SQL proved target-derived organization binding despite supplied mismatch, filtered pages beyond 25 rows, organization isolation, payload-field exclusion and anonymous/prospect/unverified denial. Viewing and seller regressions passed after introducing binding for all notification families. No real business records or emails were retained. Security advisors report the same nine informational closed internal tables with no warning/error findings ([reference](https://supabase.com/docs/guides/database/database-linter?lint=0008_rls_enabled_no_policy)).

Authenticated Resend delivery/bounce/complaint events remain the next notification integration work. Live worker/scheduler and staff browser acceptance remain pending server credentials, production configuration and assigned verified accounts. The full production plan remains active.

The refreshed preview redirects anonymous notification-monitor navigation to sign-in with private/no-store cache headers. Populated real staff walkthroughs remain pending approved assigned accounts.

## Verified Resend delivery events

`POST /api/webhooks/resend` verifies the exact bounded request body and Svix headers with the installed Resend SDK before creating a privileged database client. Only configured delivery/sent/delay/bounce/complaint/failure/suppression metadata is accepted. Open/click tracking and unrelated event families are ignored; email bodies, addresses, subject and arbitrary caller organization/outbox fields are not persisted. The endpoint requires server-only `RESEND_WEBHOOK_SECRET`, `RESEND_API_KEY` and `SUPABASE_SECRET_KEY`. It is separate from user-authenticated routes and uses the provider signature as its authority.

Private service-only event records deduplicate the stable webhook ID and reject changed identity/payload hashes. Events arriving before worker completion remain unmatched and are reconciled after the provider message ID is stored; each worker pass runs bounded reconciliation, so a concurrent callback/completion cannot lose the evidence. Provider message IDs are unique per job. Delivery summary preserves complaint/bounce/suppression/failure evidence over positive events and does not regress delivered to delayed/sent when callbacks arrive out of order. The immutable event metadata remains available for trusted reconciliation; event metadata retention is still a business policy input.

Staff monitoring now filters provider outcomes and shows organization-wide outcome totals separately from queue state. Delivery means acceptance by the recipient mail server, without asserting inbox placement or reading. A bounced/complained job remains provider-accepted in the queue; recording delivery evidence never retries or resends it. Staff cannot forge events or read the raw private event store.

Evidence: production build/typecheck, real installed SDK verification against independently generated signatures (raw-byte tampering, wrong key and stale/future timestamps), body bounds, ignored tracking/spoofed/private fields, worker and monitor checks passed. Rolled-back SQL verified early callback retention/reconciliation, replay deduplication/changed replay denial, out-of-order summary preservation, complaint filtering, foreign/unverified isolation and service-only event/reconciliation access. Enquiry/outbox regression passed. Security advisors report ten informational closed internal tables (the new private event store is deliberately service-only) and no warning/error findings ([reference](https://supabase.com/docs/guides/database/database-linter?lint=0008_rls_enabled_no_policy)). No real provider callbacks or emails were exercised, and no fixture records were retained.

Live activation still requires a deployed HTTPS endpoint, Resend webhook registration/signing secret, server credential, worker scheduling and real delivery/replay acceptance. Open-house event publishing/RSVP is the next dependency-ready engineering path; signing/legal inputs, resident activation/operations, finance/native journeys and full launch acceptance remain in the active plan.

The refreshed local preview returns 503 for the unconfigured delivery webhook and redirects anonymous delivery-filtered monitoring to sign-in. Real configured-provider acceptance remains pending.

## Open-house staff authoring (event workflow in progress)

Verified admin/realtor/manager staff can schedule an approved event from a published organization listing at `/staff/open-houses`. The host and organization derive from verified membership; private management records hold host identity/version, and immutable author events hold actor/request/reason history. Staff cannot write events/management/audit directly. New event windows are 30 minutes to 120 days ahead, 15 minutes to eight hours long, with an approved title and visitor capacity of 1–250. A daily create limit, optimistic revisions and unchanged request retries guard authoring.

The existing public event policy now hides cancelled/completed/elapsed events and requires a published listing. Same-organization staff can still read their own historical schedule. Cancellation/completion are audited, and completion requires the event end to have elapsed. Time changes use cancellation/new scheduling. Legacy records get organization management bindings with host review required; no arbitrary host was assigned.

Open houses and individual viewing slots share the existing organization scheduling lock. New authoring checks overlapping listing/host slots and events; viewing slot/property and host insertion guards reject the reverse conflicts without leaving orphan slots. Physical-unit overlap across duplicate listing IDs still needs an additional resource guard before this workflow is considered production complete.

The staff workspace separately pages events and published property choices in groups of 25, retains event-state filters and redirects out-of-range pages from counts. A changed property-choice page resets the form retry identity. Public map discovery, RSVP/visitor capacity enforcement, private meeting details, reminders and check-in attribution remain unfinished; the UI states this limitation. No event messaging was enabled in this increment.

Evidence: build/typecheck, input/API/page checks and rolled-back SQL staff/organization/host derivation, request retry, publication attestation, overlap denial in both directions, no orphan slots, completion timing, stale-version handling, cancellation release, public cancellation visibility and foreign/prospect/unverified denial passed. Viewing regression passed. Fixtures were rolled back; no real open houses or emails were retained. Security advisors report the same ten informational closed internal tables and no warning/error findings ([reference](https://supabase.com/docs/guides/database/database-linter?lint=0008_rls_enabled_no_policy)). Signed-in staff/populated browser acceptance remains pending verified assigned accounts and approved records.

Next work: physical-unit scheduling guard, geographic public discovery and RSVP/meeting-detail controls, followed by event notifications/reminders and attendance attribution. The full production goal remains active.

The refreshed preview redirects anonymous staff open-house navigation to sign-in and denies anonymous authoring POSTs with 401. No live event was created by these runtime checks.

### Managed resource scheduling guard

Applied migration `20261007044333_managed_resource_schedule_guard`. Appointment conflicts now compare the physical unit across duplicate listings. A whole-property appointment also conflicts with appointments in any of its units; two distinct units can be scheduled concurrently by different hosts. Future active appointments prevent listing property/unit/organization rebinding until the appointments are resolved. Database triggers enforce both viewing-to-open-house and open-house-to-viewing directions, including trusted direct writes, with organization scheduling locks and listing row locks.

Verification: rolled-back `scripts/sql/verify-managed-resource-schedule.sql` proves duplicate-unit viewing/event rejection with different hosts, whole-property overlap rejection, distinct-unit availability, resource rebinding rejection and release after cancellation/closure. Existing open-house authoring and complete viewing SQL regressions passed. No fixtures retained or email sent. Concurrent load testing remains outstanding; PostgreSQL deadlock/serialization failures must be retried after refresh. Next: public geographic open-house discovery, verified prospect RSVP/capacity management, reminders and attendance.

### Public open-house discovery and verified prospect RSVPs

Added `/open-houses` with neighborhood/intent filters, count-first ordered 24-event pagination, list/map modes and approved approximate locations. Only upcoming scheduled events on published listings are selected; host identity, private addresses and attendee identity are not selected publicly. Events without pins remain in the list. The header links the experience. The property enquiry panel now has an anchor for event follow-up.

Applied migration `20261007044635_open_house_prospect_rsvp`: verified-account RPC derives user/organization, checks hosted published event availability, enforces parties of 1–6 and total capacity under event-row locks, prevents overlapping open-house reservations for a prospect, requires contact consent, supports versioned changes/cancellation and records request-id audit for safe retries. RLS permits only own prospect records or verified organization staff; direct client writes and anonymous identity reads are denied. Event cancellation prevents new reservations; prior attendees can still cancel their own records. Private `/account/open-houses` provides 25-row count-first pagination and cancel/update controls. Cancelled/past/unpublished events show an unavailable warning rather than implying attendance is valid.

Verification: `npm run test:open-houses`, typecheck and production build passed. Rolled-back `scripts/sql/verify-open-house-rsvps.sql` proves retry deduplication, changed-request rejection, stale revision conflict, capacity limit, overlapping-event rejection, consent, own-user/foreign-org privacy, verified staff reads, unverified/anonymous denial, cancelled-event rejection and own cancellation. Live preview `/open-houses` returns HTTP 200 with the truthful empty state; anonymous RSVP returns 401; private history redirects to sign-in. No real events/RSVPs retained. Supabase advisors have no WARN/ERROR, only 10 INFO intentionally policy-closed internal tables (https://supabase.com/docs/guides/database/database-linter?lint=0008_rls_enabled_no_policy).

Remaining for open houses: immutable attendee event/title/time snapshots for historical context, staff attendee roster and attendance attribution, private arrival details, notifications/reminders/cancellation notices, prospect conflict coordination with individual viewings, concurrent capacity load test and signed-in browser acceptance with approved real accounts/inventory. Public map pins remain approximate; no navigation to a private street address is implied. Global launch inputs and broader role/native milestones remain open.

### Reservation event history

Applied `20261007045114_open_house_reservation_history`: RSVP creation captures trusted event title, public neighborhood and start/end times. The database derives these fields and rejects later identity/event/organization or snapshot rebinding, including service-role writes. Existing rows, if present, are explicitly backfilled from current event details at migration time. No private address or host identity is captured. Account history uses these snapshots even when cancelled/past events disappear under public RLS; live event availability remains separate from historical context.

Verification: expanded rolled-back RSVP SQL proves original history survives cancellation/title changes, own-user snapshots remain readable without exposing the cancelled event, and history/user rebinding are denied. Account page verifier renders an unavailable event with its original title, neighborhood and cancellation state. Open-house checks, typecheck and production build passed. Security advisors still show no WARN/ERROR, only 10 INFO intentionally closed internal tables. Preview process is serving the previous verified build until the next restart; no signed-in browser acceptance is claimed. Next: verified staff attendee roster, attendance audit and approved arrival details, followed by transactional reminders/cancellation notices and cross-workflow prospect scheduling.

### Verified organization staff attendee roster

Applied `20261007045303_open_house_staff_roster`. New `/staff/open-houses/[eventId]` links from the staff schedule and shows 25 parties per page, reserved/cancelled filters, reserved-place totals and remaining capacity for scheduled events. Cancelled/completed events explicitly show historical totals. Contact email is returned only by a private security-definer helper after verified staff organization/event authorization; the public wrapper uses security invoker. No submitted organization ID determines access. No user ID, account metadata, private address or host identity is returned in roster rows. Unverified attendee emails are withheld; RSVP history remains private.

Verification: rolled-back 28-party SQL fixture proves bounded pagination, clipped pages, state filters, party/capacity totals, verified emails and foreign/unverified/prospect/anonymous contact denial. Staff roster page verifier proves role gates, UUID validation, normalized filters, canonical pagination and private-event handling. `npm run test:open-houses`, typecheck and production build passed. Preview restarted on port 3001 with this build; anonymous roster access redirects to sign-in and public discovery remains available. Security advisors: no WARN/ERROR, 10 INFO intentionally closed internal tables (https://supabase.com/docs/guides/database/database-linter?lint=0008_rls_enabled_no_policy). No fixtures persisted, no email sent. Signed-in browser acceptance remains pending real verified accounts and approved content. Next: attendance/check-in audit and authorized arrival instructions, transactional reminders/cancellation notices, then cross-workflow scheduling coordination.

### Open-house attendance and correction audit

Applied `20261007045604_open_house_attendance`. Verified organization staff can record actual attending counts or no-shows from the private roster, or clear an incorrect record with a reason. The database enforces counts within the reserved party, revision checks and request-id retries, derives the actor/organization and records every change in a staff-only audit table. Check-in opens 30 minutes before the event; changes close seven days after its end. No-show records require an ended event. Cancelled events cannot gain attendance but existing incorrect records can be cleared within the correction window. Recorded attendance blocks prospect changes to party size/status until staff clears it, preventing history from being silently invalidated. Attendees can see their own outcome without reading internal staff reasons or actor records.

Verification: rolled-back `scripts/sql/verify-open-house-attendance.sql` proves early/window/no-show/count validation, retry deduplication and changed-request/stale revision rejection, prospect/foreign/unverified write denial, private audit isolation, direct staff write denial, corrections and RSVP release after clearing. Existing RSVP/history and roster SQL regressions passed. API and rendered UI checks verify authority stripping, origin/body limits and locked RSVP controls. `npm run test:open-houses`, typecheck and final production build passed. Preview refreshed; live anonymous attendance API returns 401. Security advisors remain 10 INFO for intentionally closed tables, no WARN/ERROR. No fixtures or emails retained/sent; signed-in browser acceptance is still pending approved accounts/events.

Next: staff audit-history browser with actor attribution, approved private arrival instructions and transactional RSVP/reminder/cancellation notices. Attendance conversion analytics, cross-workflow prospect scheduling, concurrency testing and wider role/native milestones remain open. The full production objective remains active.

### Staff attendance audit browser

Added `/staff/open-houses/[eventId]/attendance`, linked from the attendee roster. It verifies the event's organization before querying staff-only attendance changes, uses count-first ordered 25-change pagination and shows outcome, correction reason, timestamp, revision, reservation and actor references. Current staff names come from the existing authorized staff directory; immutable actor references remain visible for former staff. Names are explicitly described as current rather than historical identity snapshots. No new database privileges or policies were added.

Verification: new audit page verifier proves organization/event query scope, pre-query authorization, malformed identifier rejection, count clipping and failure behavior. Existing open-house checks, typecheck and production build passed. Signed-in browser acceptance remains pending approved accounts/content. Next: approved private arrival instructions and transactional notifications/reminders; the full development plan remains active.

Audit runtime checkpoint: preview refreshed on port 3001; anonymous attendance-history access redirects to sign-in. No authenticated browser acceptance or real event data is claimed.

### Approved private open-house arrival instructions

Applied `20261007050240_open_house_private_arrival`. Staff approve/revise/withdraw a meeting point, directions and optional paired exact coordinates at `/staff/open-houses/[eventId]/arrival`, linked from the roster. Changes derive organization/actor, require a reason and explicit approval, and preserve version/request-id audit. Direct client writes are denied. Public catalog/map queries remain approximate and do not select this table.

Verified attendees with a current going RSVP can read active directions only from 24 hours before the event until its end, and only while the event is scheduled and its listing published. RLS blocks anonymous/unverified/unreserved/foreign access, cancelled RSVPs, withdrawn directions, cancelled/ended events and unpublished listings. Staff retain organization-scoped review access. Account history queries only the current 25-row page of RSVP event IDs and shows eligible directions plus an optional user-initiated map navigation link; unavailable instructions direct attendees to contact the team. No private coordinates are embedded in public maps or frozen in email bodies. The 24-hour disclosure window is the implemented operational default.

Verification: rolled-back arrival SQL proves approval/coordinate validation (including NaN), retry deduplication, stale edits, direct write denial and every disclosure/revocation condition above. Arrival API and editor page checks plus existing open-house suite passed. One initial native Node/V8 process crashed; the unchanged full suite passed on immediate rerun. Typecheck and production build passed. Security advisors: no WARN/ERROR, 10 INFO intentionally closed tables. Preview refreshed; anonymous editor redirects and API returns 401. No real private directions, events or emails were created; signed-in browser acceptance remains pending approved accounts/inventory.

Next: arrival change-history browser, transactional RSVP confirmations/reminders/event cancellation notices and cross-workflow prospect scheduling. Full production role/native/launch work remains open.

### Private arrival-instruction change history

Added `/staff/open-houses/[eventId]/arrival/history`, linked from the arrival editor. Verified staff see approval/withdrawal state, prior meeting instructions/coordinates, reasons, revisions, timestamps and immutable actor references. Current names use the existing authorized staff directory. Queries verify event organization before reading history and apply explicit event/organization filters, count-first ordered 25-row pagination and existing staff-only RLS. No new database privilege or policy was added. Historical private directions are not exposed to attendees.

Verification: arrival-history page test proves authorization before reads, organization/event scope, malformed identifiers, clipped pagination and query failure behavior. Open-house suite, typecheck and production build passed. Preview refreshed; anonymous history access redirects to sign-in. Signed-in browser acceptance remains outstanding. Notification worker review confirms the next implementation should extend the existing outbox/claim/preflight/delivery-monitor path with RSVP/event sources, preserving safe retries and excluding private arrival details from email snapshots. No event notices/reminders send yet; required worker credentials and scheduler remain launch inputs.

### Open-house transactional notification integration

Applied `20261007051056_open_house_transactional_notices`, `20261007051209_open_house_notice_currency_guard`, `20261007051610_open_house_notice_republication_guard` and `20261007051643_open_house_notice_record_binding`. Verified RSVP changes now queue confirmations and future 24-hour reminders; RSVP cancellation, event cancellation, listing withdrawal and approved arrival changes queue notices through the existing outbox. Recipient/organization are derived from verified account and reservation records. Every notice links to private account history; meeting points, directions and exact coordinates are excluded from email snapshots. RSVP edits are bounded to 30 reserve/update actions per account/day, while cancellation remains available.

The existing service-only transactional claim freezes sender, recipient, body and canonical link on first attempt. Older two-argument workers cannot claim link-bearing open-house notices. Preflight checks current RSVP revision, verified email, event/publication state, expiry and latest arrival revision. Obsolete queued/processing jobs are superseded; publication restoration retires unavailable notices before another withdrawal can create a new one. Existing accepted sends remain history, and an already in-flight provider request cannot be recalled by preflight. Superseded completion races remain reported as uncertain and require review; live concurrency and provider acceptance still need validation.

Both notification monitors support the `open_house` family and retain metadata-only organization scope, delivery callbacks and 25-job pagination. No separate provider-send path was introduced. The publication branch initially exposed a PL/pgSQL record/alias conflict; the corrective migration fixed it and the full publication-cycle fixture passed afterward.

Verification: rolled-back open-house notification SQL proves trigger idempotency, derived recipient/org, reminder schedule, frozen retries, legacy-worker exclusion, current attempt guards, private-location exclusion, arrival supersession, publication cycles, event/RSVP cancellation and expiry. Separate SQL proves the daily update limit and unrestricted cancellation. Existing enquiry, co-signer notification, Resend delivery and RSVP/history SQL regressions passed. Notification worker/monitor/webhook tests and open-house suite passed; production build passed. Security advisors show no WARN/ERROR, 11 INFO intentionally closed internal tables including private notice sources ([advisory reference](https://supabase.com/docs/guides/database/database-linter?lint=0008_rls_enabled_no_policy)). No fixtures retained or emails sent. Missing server credential, cron secret/scheduling, canonical production URL and signed webhook setup remain launch inputs. Next: cross-workflow prospect scheduling, concurrent capacity/claim acceptance, and further production milestones.

Notification runtime checkpoint: preview refreshed; anonymous worker invocation returns 401 and private open-house monitor access redirects to sign-in. No actual provider send or scheduled production worker run was performed.

### Prospect calendar coordination

Applied `20261007052000_prospect_cross_workflow_calendar`, `20261007052133_prospect_calendar_active_guard` and `20261007052508_reserved_open_house_schedule_guard`. Viewing requests/confirmations and open-house reservations share a prospect advisory lock and reject overlapping active appointments. Expired viewing holds stop blocking; exact end/start boundaries remain available. Existing reservation history prevents changing an event's listing or times: staff must cancel and create a replacement event, preserving the original attendee snapshot and notice history. Unchanged writes remain allowed. Viewing API maps calendar conflicts and transaction retry errors to a safe 409 response without exposing database details.

Verification: rolled-back `scripts/sql/verify-prospect-cross-calendar.sql` proves conflicts in both directions, expired holds, separate prospects, adjacent appointments, confirmed viewing cancellation/release and reserved event schedule protection. Existing viewing and RSVP SQL regressions, viewing API and open-house tests, and production build passed. No fixtures persisted. Security review before the final schedule guard showed no WARN/ERROR and 11 INFO intentionally closed internal tables. Actual multi-session concurrency, signed-in browser acceptance and live provider delivery remain unproven. The full production plan remains active; all role, finance, native and launch milestones retain their scope.

### Verified working-preference persistence

Applied `20261007052640_verified_matching_preferences`. Matching preference saves/deletions now use a verified-account RPC through a bounded same-origin API. Direct authenticated table writes are revoked; own-row reads remain available. The database derives the user and consent timestamp, validates allowed answers and a bounded area, serializes writes per account and rejects stale UUID revisions. Explicit consent is required for every save; deletion needs no renewed consent and erases the stored answers. Browser controls clear the consent checkbox after success. Account navigation links to these controls, and existing saved answers remain manageable when the published realtor roster is empty or unavailable. Matching reasons and eligibility ranking retain their existing behavior.

Verification: rolled-back SQL proves consent/answer bounds, trusted identity/time, direct-write denial, own-row isolation, foreign deletion denial, unverified/anonymous denial, revision replacement, stale save/delete rejection and removal. API tests prove origin/auth/body bounds, authority stripping, deletion arguments and safe conflict responses. Discovery checks, typecheck and final production build passed. Security advisors show no WARN/ERROR; 11 INFO intentionally closed internal tables remain ([reference](https://supabase.com/docs/guides/database/database-linter?lint=0008_rls_enabled_no_policy)). No test answers or accounts were retained. Signed-in browser acceptance remains pending verified accounts; approved realtor authoring and the wider production milestones remain unfinished.

### Audited realtor profile authoring

The existing staff realtor form now calls `author_realtor_profile`, introduced in `20261007053018_audited_realtor_authoring`. Verified catalog staff edit only their organization. Direct authenticated profile writes are revoked. Every save requires a change reason; published profiles require explicit renewed approval plus complete biography, coverage and intents. The database normalizes service arrays, validates styles/text/photo URLs, derives organization/actor, serializes organization edits and rejects stale revisions. Request IDs deduplicate identical retries and reject changed retry payloads. Browser retries preserve a request ID when the outcome is uncertain and content is unchanged. Saving returns to the realtor catalog.

Private `/staff/realtors/[profileId]/history` shows before/after field changes, reason, approval, revisions and immutable actor references with current directory names. Profile organization is verified before history reads; history uses explicit organization/profile filters and count-first 25-row pagination. Baseline content predating this migration has no reconstructed approval history. The staff catalog selector still loads at most 200 recent profiles; a fully paginated catalog browser remains a scalability follow-up.

Verification: rolled-back SQL proves explicit publication approval, normalization/authority, malformed arrays/credential URLs, retry deduplication and changed retry rejection, immutable client audit, direct profile write denial, stale edit rejection, withdrawal snapshots and foreign/unverified/prospect/anonymous isolation. API tests verify origin/auth/body limits, trusted RPC arguments and safe errors. Rendered editor checks prove required reason, fresh unchecked approval, existing publication/content, longer coverage inputs and history navigation. History page checks prove pre-read authorization, organization/profile scoping and pagination. Catalog/discovery checks, typecheck and final production build passed. Security advisors remain no WARN/ERROR and 11 INFO intentionally closed internal tables. No fixture profiles/accounts were retained and no emails sent. Signed-in browser acceptance and approved live profiles remain pending; the full production goal remains active.

### Staff catalog pagination and exact-record navigation

Replaced the two 200-row staff catalog loads with a selected-type, count-first 25-record browser. Properties and realtor profiles have title/name search, publication filters, stable created-time/ID ordering and filter-preserving page links. Search escapes SQL wildcard characters. Counts and rows explicitly scope organization; exact listing/realtor UUID links also apply organization scope and bypass browse filters, allowing older records to be edited. Conflicting/malformed exact identifiers fail before reads. Catalog switching requests the chosen server page; successful saves open the exact record rather than resetting to a different catalog. Existing property handoff links remain compatible.

Verification: staff page tests prove active-type-only reads, count-before-range, 25-record windows, clipped pages, normalized filters, literal search, organization scope, exact-record lookup and authorization/failure behavior. Rolled-back SQL with 62 records of each type proves real final/second-page sizes, literal wildcard search, foreign published-profile exclusion from staff scope and public draft denial. Catalog validation/API/history/editor regressions, typecheck and final production build passed. No DDL, privilege changes or retained fixture data. Signed-in interaction acceptance remains pending real verified staff accounts. The full role/native/finance/launch plan stays active.

### First-administrator bootstrap prerequisite

Added `scripts/generate-admin-bootstrap.cjs`, which generates a reviewable transaction for an explicitly approved email and existing organization UUID. It does not connect to services or execute its output. The trusted transaction derives the user from exactly one matching account, requires email verification, locks organization/account, and inserts only the first administrator. Identical retries return without another insert. Existing non-admin memberships cannot be promoted, other organizations cannot be reassigned, and another existing administrator requires the future membership management workflow. No real administrator identity was inferred from the enquiry recipient or demo identities.

Verification: input/literal-boundary checks pass, including apostrophe quoting and missing/malformed input rejection. Rolled-back database fixture proves first creation, retry idempotency, cross-organization denial, existing-role upgrade denial, another-administrator denial, missing/unverified account denial and missing organization denial. No accounts, memberships or organizations were retained. No schema, API or preview changes occurred, so a new web build was not needed. The service setup guide now reflects implemented staff workflows and records the trusted execution prerequisite. Approved first-admin/organization inputs, actual execution and signup/recovery delivery remain launch dependencies. General staff invitations, audited membership assignment/revocation, last-admin protection and the wider full-platform plan remain unfinished.

### Audited administrator staff membership management

Applied `20261007054101_audited_staff_membership`. Verified organization administrators manage existing verified accounts at `/staff/memberships`, assigning current staff roles or revoking access after recording approval and a reason. The database derives actor/organization, serializes organization changes on the bootstrap lock, rechecks administrator authority after locking, locks the target account and rejects cross-organization membership changes. Random membership revisions detect stale edits and stale revocations after reassignment. Identical request retries return their original outcome; changed retry content is rejected. Unverified members can be revoked but cannot gain a role. Last-admin demotion/revocation requires another verified administrator; an unverified admin does not satisfy this requirement.

The administrator-only directory derives current email verification from Auth and returns at most 25 rows with clipped pagination. `/staff/memberships/history` provides count-first 25-change audit pages with immutable actor/account references, email-at-change, previous/new roles and reasons. Direct membership/audit writes remain denied to browser clients. Own-membership reads and other existing role authority remain database-derived. Revocation removes staff authority on subsequent checks; it does not terminate prospect sessions, undo earlier work or cancel in-flight operations. Trusted service/SQL/Auth deletion is outside this workflow's last-admin guard and remains an operational control. Staff invitation emails and separate resident/contractor/security/owner authorization are still pending.

Verification: rolled-back SQL proves approval/verified-account requirements, derived audit, direct-write/audit-delete denial, idempotency and changed retry rejection, stale role changes, last-verified-admin protection, handover, self-demotion authority loss, unverified revocation, regrant/stale revoke protection, foreign/prospect/anonymous isolation and bounded 32-member directory pages. API and rendered page checks prove admin/origin/body guards, authority stripping, roles/revisions, fresh approval/reason controls and bounded audit reads. One initial UI test incorrectly assumed HTML attribute order; its order-independent assertion passed afterward. Catalog regressions, typecheck and production build passed. Security advisors: no WARN/ERROR, 11 INFO intentionally closed internal tables ([reference](https://supabase.com/docs/guides/database/database-linter?lint=0008_rls_enabled_no_policy)). Preview refreshed; anonymous pages redirect and API returns 401. No fixture staff/account/organization records retained or emails sent. Signed-in browser and actual multi-session concurrency acceptance remain unproven; the full production goal stays active.

### Managed property work-order intake and triage

Applied `20261007054742_managed_work_order_intake` and `20261007055158_work_order_unit_history_guard`. Existing closed work-order primitives now support verified organization manager/admin reporting against private properties/units, with organization/reporter derivation, revisioned triage/priority decisions and cancellation. Client direct writes are denied. Reasoned changes preserve actor, prior/new state/priority and request payload; identical retries reuse outcomes and changed retry content fails. Creation is capped at 30 per actor/database day, with cancellation still available. Shared organization locking coordinates authority rechecks with staff membership changes. Resource/reporter binding is immutable; property organization and referenced unit parent changes are blocked, including trusted updates. Unit/property row locks protect binding during creation.

`/staff/work-orders` provides filtered 25-record queues. Reporting starts from a selected private property; unit choices paginate independently. Private work-order detail includes authorized transitions and count-first 25-change history. Only reported/triaged orders expose these actions. No resident/contractor/security role is fabricated, and no completion, dispatch, SLA, email or ledger effect is claimed. These remain the next shared maintenance increments alongside the full resident/signing, finance, owner, native and launch scope.

Verification: rolled-back SQL proves property/unit organization isolation, derived actor/org, retry and changed-payload checks, stale triage, lifecycle/cancel guards, priority audit, 30-create bound with cancellation availability, direct work/audit write denial, immutable resource/property/unit linkage and realtor/foreign/unverified/prospect/anonymous denial. API tests prove body/origin/role bounds and stripping of organization/reporter/state authority. Server-page tests prove authorization-before-read, queue/unit/history pagination, scoped records and closed-transition rendering. Inventory and staff-membership regressions, typecheck and production build passed. Security advisors: no WARN/ERROR; 10 INFO intentionally closed internal tables remain, one fewer because work orders now have scoped RLS. Preview refreshed; anonymous pages redirect and API returns 401. No fixture records retained or emails sent. Actual multi-session concurrency and signed-in acceptance remain unproven. Full production objective remains active.

### Approved contractor identity and trade coverage

Applied `20261007055530_approved_contractor_identity`. Organization managers/admins register existing verified accounts with an approved contractor/company name, normalized trade coverage, approval and reason. Registrations are unique per organization/account; separate organization approvals are supported. Organization/account binding is immutable even for trusted updates. Revisioned changes and deactivation preserve private actor/before/after audit and request payloads; identical retries return original outcomes and changed retries fail. Activating an unverified account is denied; management can retain/deactivate an unverified registration. Direct browser writes and self-approval are denied. Verified account owners can read their own registration state but not internal approval notes.

`/staff/contractors` supplies a management-only filtered 25-record register and creation form. Exact registration detail verifies organization before reads, supports approved edits/deactivation and count-first 25-change history. This establishes identity only: work offers/acceptance, assignment-scoped job data, contractor account portal, scheduling, evidence, notices and security entry remain the next shared maintenance workflow. No work-order/property/resident access is granted by registration alone.

Verification: rolled-back SQL proves verification/approval, normalization, derived identity/organization, duplicate registration prevention, retry/stale checks, direct-write/audit-delete denial, deactivation snapshots, immutable trusted identity, own-row reads across separate approvals and foreign/realtor/unverified/prospect/anonymous isolation. API tests prove approved content/body/origin/role bounds and authority stripping. Register/history page tests prove authorization-before-read, scope/pagination and fresh approval/immutable identity form controls. Work-order regressions, typecheck and production build passed. Security advisors remain no WARN/ERROR and 10 INFO intentionally closed tables ([reference](https://supabase.com/docs/guides/database/database-linter?lint=0008_rls_enabled_no_policy)). Preview refreshed; anonymous pages redirect and API returns 401. No fixture identities/organizations retained or emails sent. Signed-in acceptance and actual multi-session concurrency remain unproven. Full production goal remains active.


### Contractor work offer database engine

Applied `20261007060427_contractor_work_offers`. Management can issue one active offer per triaged work order to an approved active verified contractor with matching trade. Explicitly approved title/scope/company snapshots are immutable, offers expire after seven days, and contractors read only their approved offer data. Internal work descriptions and management audit reasons remain inaccessible. Owner-only acceptance assigns work and records an audit; decline, management withdrawal and contractor release are revisioned. Withdrawal/release before scheduling returns work to triage. Changed work triage or contractor registration retires pending offers. Accepted work blocks contractor deactivation/removal of its trade until resolved. Identical retries reuse outcomes.

Verification: `scripts/sql/verify-contractor-work-offers.sql` ran successfully in a rolled-back transaction covering offer retry, duplicate active offer denial, prospect rejection, contractor scope/privacy, acceptance retry and assignment audit, accepted-contractor deactivation guard, management withdrawal, triage retirement, registry retirement, decline, stale release denial, contractor release, expiry and foreign-manager isolation. No test data persisted. Security advisors report no WARN/ERROR and the existing 10 INFO intentionally closed tables ([reference](https://supabase.com/docs/guides/database/database-linter?lint=0008_rls_enabled_no_policy)). This is a database checkpoint only; API/forms/contractor portal, signed-in and real multi-session acceptance, scheduling, entry authorization, evidence and completion remain open. No web code changed in this increment, so no new web build was needed. Full production goal remains active.


### Work offer API boundary

Added `POST /api/work-offers` and strict action-specific validation. Verified sign-in is required; offer/withdraw additionally requires current management membership. Contractor responses delegate ownership and current registration checks to the existing database engine. Actor and organization inputs are stripped, responses cannot alter shared scope, revisions are bounded, and origin/JSON/body-size checks precede RPC calls. Conflicts and permission errors return safe messages. `npm run test:work-offers` passes mocked API boundary checks; TypeScript and the production build pass. Contractor screens and real signed-in end-to-end acceptance remain open.


### Contractor offer workspace

Added verified account `/account/work-offers` and exact offer detail, linked from the account. Queries explicitly restrict offers to active registrations belonging to the signed-in user, even when that account also has management rights. Queue counts precede 25-row pagination; no internal work-order or audit queries occur. Approved snapshot detail renders accept/decline for current unexpired offers and release for accepted assignments. Confirmation and reason are required. Stable request IDs survive unchanged uncertain retries. The screen explains scheduling/entry remain separate.

API and rendered server-page checks pass, including sign-in-before-read, absent registration, ownership predicates, pagination, malformed references, expired/closed action hiding and accepted release. TypeScript and production build pass. Signed-in browser acceptance, management offer creation and later scheduling/entry/evidence/completion remain open. No real account or job data created.


### Management work offer creation

Work-order detail now links to an organization-scoped offer page. Triaged work supports count-first 25-contractor selection and exact selected contractor checks against the same organization/active register. The manager writes a separate shared title/scope, selects an approved trade and records internal reason/fresh explicit sharing approval. Internal issue content is not prefilled. Current pending/accepted offer shows its snapshot and withdrawal action; expired pending offers permit database-controlled replacement. Stable nonces preserve unchanged uncertain retries.

Management rendered page/form tests, existing offer API/contractor page tests, work-order regressions, TypeScript and production build pass. Signed-in end-to-end acceptance, offer audit history, scheduling, entry authorization, evidence, completion and notices remain open. No real records or email created.


### Management offer history

Added `/staff/work-orders/[workOrderId]/offers/history` linked from work-order detail. Management can page through every prior approved offer snapshot, then inspect the selected offer's immutable internal change records. Both modes count before reading 25 rows. Work order, selected offer and organization bindings are checked before audit queries. Recorded states are kept distinct from elapsed expiry awaiting a database transition. Contractor account screens continue to exclude these internal audits.

Rendered server-page checks prove management-before-read, work/organization/selected-offer binding, audit scoping, absent offer denial and clipped pagination; full focused work-offer checks, TypeScript and production build pass. Signed-in browser, actual multi-session acceptance, scheduling, entry/evidence/completion and notification integration remain open. No production data changed.


### Contractor visit scheduling database engine

Applied `20261007061712_contractor_visit_scheduling`. Verified management proposes an immutable future visit window/note for a current accepted assignment (up to 90 days ahead and eight hours duration). The assigned active verified contractor confirms/declines; authorized manager or contractor can cancel. Proposed/confirmed visits reserve the contractor identity across organizations and the managed property/unit; adjacent windows remain valid. Contractor/property/organization locks coordinate lifecycle checks, with fresh authority checked after locking. Confirmation schedules the work order and updates assignment revision; cancellation before progression restores assigned work and clears dates. Active visits must be cancelled before withdrawing an assignment. Client writes are denied; contractor reads exclude internal visit audit reasons. This grants no entry rights.

Rolled-back SQL checks pass for proposal/confirmation retries, duplicate active visit rejection, future bounds, different-job contractor overlap rejection and adjacent acceptance, manager impersonation rejection, contractor scoped reads/audit privacy, confirmation state/date/audit, stale cancellation, cancel-to-assigned, replacement decline, foreign-manager isolation and immutable trusted visit schedule. Existing offer fixture passes regression after migration. No data retained. Security advisors: no WARN/ERROR, existing 10 INFO intentionally closed tables ([reference](https://supabase.com/docs/guides/database/database-linter?lint=0008_rls_enabled_no_policy)). Scheduling API/UI and history, actual multi-session overlap proof, cross-workflow calendar checks, signed-in browser acceptance and later entry/evidence/completion/notices remain open. No web changes occurred, so a build was not repeated. Full production goal remains active.


### Contractor visit API

Added verified `POST /api/contractor-visits`. Management is required to propose; participant response/cancellation ownership is rechecked by the database. Action-specific validation strips caller-supplied organization/contractor identity, requires canonical valid UTC timestamps and a positive window up to eight hours, bounds revisions and shared/internal text, and requires explicit sharing approval. Response actions cannot rewrite appointment fields. Origin, JSON and 8000-byte body checks guard calls; safe permission/conflict errors avoid internal details. Database time enforces future/90-day limits and overlap checks after retry handling.

Focused API checks pass for access/origin/size, management-only proposal, malformed/impossible/timezone-free timestamps, eight-hour boundary, immutable response schedule, identity stripping and safe conflict responses. TypeScript and production build pass. Scheduling screens, visit history, signed-in acceptance, actual concurrent scheduling and later entry/evidence/completion/notices remain unfinished. No production data changed.


### Contractor appointment screens

Added management scheduling from work-order detail, scoped to the verified organization/work and accepted offer. Management proposes a future window/shared note with fresh approval, or cancels a current active appointment. Progressed work hides cancellation controls; database checks remain authoritative. Contractor offer detail explicitly scopes current visits by offer/user, displays shared window/note and supports future proposal confirmation, decline and cancellation. Assignment release is hidden while an appointment is active. No internal visit history is queried for contractors. Appointment approval remains distinct from property entry authorization.

Date inputs use Jamaica (UTC−5), converted explicitly to canonical UTC independently of the browser timezone; impossible dates are rejected. Forms retain request nonces for unchanged uncertain retries, require a decision reason and explicit confirmation/approval, and reload their exact current page after success. Focused management page/time tests, contractor response rendering/ownership checks, offer/API regressions, TypeScript and production build pass. Visit history, cross-workflow calendars, actual concurrency, signed-in browser, entry/evidence/completion/notices remain open. No real appointments created.


### Management appointment history

Scheduling now links to `/staff/work-orders/[workOrderId]/visits/history`. The history covers visits across past assignments using an inner offer relationship constrained to the selected organization/work order. A selected visit is checked against that same parent before any internal audit query. Window/state/shared note snapshots and manager-only actor/decision history have independent count-first 25-row pagination. Contractor screens do not gain internal history access.

Rendered history checks pass for management-before-read, work/organization/selected-visit binding, audit scoping, absent visit denial and clipped pagination. Scheduling API/page/time regressions, TypeScript and production build pass. Real authenticated Data API/browser acceptance, actual multi-session and cross-workflow calendar checks, entry authorization, evidence/completion and notification integration remain open. No production records changed.


### Maintenance calendar interoperability

Applied `20261007062350_maintenance_cross_workflow_calendar`. Contractor visit proposals/confirmations now share the existing prospect identity and organization resource calendar locks before their maintenance locks. Appointment guards reject active viewing holds, confirmed viewings and scheduled going RSVPs for the contractor. Viewing/RSVP guards reciprocally reject proposed/confirmed contractor windows. Managed viewing slots/open houses and maintenance visits reciprocally reserve mapped properties/units; whole-property windows cover all units. Adjacent windows are allowed and expired viewing holds do not block. Closed/cancelled calendar rows are excluded. No entry rights or notifications are added.

`verify-maintenance-cross-calendar.sql` runs the visit lifecycle fixture then proves both directions of contractor identity overlap, expiry reuse, maintenance-to-viewing-slot/open-house location rejection and viewing-slot-to-maintenance location rejection. Existing prospect cross-calendar fixture also passes. Fixtures roll back without retained data. Security advisors remain no WARN/ERROR and 10 INFO intentionally closed tables ([reference](https://supabase.com/docs/guides/database/database-linter?lint=0008_rls_enabled_no_policy)). Actual simultaneous transaction behavior and signed-in end-to-end acceptance remain unproven. Public schedule rows without a managed property binding cannot establish physical resource equivalence. No web changes occurred, so build was not repeated. Entry authorization, evidence/completion/notices and the full production goal remain active.


### Management entry authorization database engine

Applied `20261007062659_contractor_entry_authorization`. Verified management can authorize one immutable, appointment-bounded access window/instruction snapshot for a currently confirmed visit on scheduled accepted work. Explicit approval and an internal authority reason are required; no owner/resident consent is inferred. Permit creation/revocation is revisioned, organization-locked, rechecks manager authority and preserves actor/request/reason history. Identical retries reuse outcomes; stale/duplicate decisions are rejected. Appointment cancellation automatically revokes authorized permits and records its source. Assigned active verified contractors read their own shared permit records but not internal decisions.

Rolled-back tests pass for sharing approval, window bounds, retry/audit deduplication, duplicate active authorization, stale revocation, contractor scope/privacy and self-authorization denial, explicit revoke/re-authorize, automatic cancellation revocation/audit, foreign-manager denial, immutable trusted scope and declined-visit denial. Maintenance cross-calendar regression passes. Fixtures roll back. Security advisors remain no WARN/ERROR and 10 INFO intentionally closed tables ([reference](https://supabase.com/docs/guides/database/database-linter?lint=0008_rls_enabled_no_policy)). This is authorization storage/workflow only: actual entry must additionally check current permit/window, appointment/work status and verified security authority. Entry API/UI/history, security identity/check-in/out, evidence/completion and notices remain pending, as do signed-in and actual concurrency acceptance. No real access granted. No web changes/build repetition.


### Management entry-permit API

Added `POST /api/staff/entry-permits` for current verified manager/admin authorization and revocation. Origin/JSON/8000-byte body guards, canonical valid UTC timestamps, positive access windows up to eight hours, bounded revisions and shared instructions, ten-character minimum authority reason and explicit authorization approval are enforced. Browser actor/organization/contractor fields are stripped. Revocation cannot change the approved access window or instructions. Database confirmation/window/current assignment checks remain authoritative. Safe permission/conflict responses hide internal error details.

Focused API checks prove verified management for both actions, reference/action/date/duration/revision/approval/reason bounds, response scope protection, identity stripping, body/origin limits and safe conflict errors. TypeScript and production build pass. Entry screens/history, verified security check-in/out, actual concurrency, signed-in acceptance, evidence/completion/notices remain open. No real access authorized.


### Entry authorization screens

Management scheduling now links to `/staff/work-orders/[workOrderId]/entry`. The page verifies organization/work, accepted assignment, confirmed appointment and active permit before reads/actions. It supports approval of a window within the appointment using explicit Jamaica-time inputs, shared instructions, access authority reason and fresh approval. Elapsed or progressed appointments hide new authorization controls. Current authorization can be revoked. Contractor offer detail reads its own current shared permit by visit/user only; internal decisions remain excluded. Display distinguishes elapsed authorization and makes representative identity/current-permission verification explicit.

Focused management page checks pass for parent/assignment/visit/permit scope, authorization/revocation lifecycle, elapsed/progressed hiding and sign-in/role-before-read. Contractor checks prove own visit/user permit predicates and no internal decision reads. API/offer regressions, TypeScript and production build pass. Forms retain stable unchanged retry IDs. No real access granted. Entry history, security staffing/check-in/out, signed-in acceptance, actual concurrency, evidence/completion/notices remain open.


### Management entry decision history

Added `/staff/work-orders/[workOrderId]/entry/history`, linked from the access decision screen. Management can review every prior permit across work-order assignments/appointments and inspect selected permit actor/reason/state history. Inner visit/offer relationships bind each selected permit and queue to the same organization/work order before audit reads. Both modes count before 25-row reads. Contractors retain shared current permit access only and do not gain internal audit reads.

Rendered history tests prove management-before-read, parent/selected-permit binding, audit scope, unavailable record denial and clipped pagination. Entry API/page regressions, TypeScript and production build pass. Authenticated Data API/browser acceptance, actual concurrency, verified security staffing/check-in/out, evidence/completion/notices and full launch acceptance remain open. No real access or records changed.


### Verified property security assignment database engine

Applied `20261007063324_verified_property_security_assignments`. Organization managers/admins approve an existing verified account for one managed property, with explicit approval/reason, immutable user/property/organization binding and unique property/account assignment. Organization locks coordinate authority rechecks and revisioned activation/deactivation. Active assignments require current Auth verification; unverified assignments can remain/deactivate. Identical retries reuse audit outcomes. Verified users can read their own assignment state while internal approval reasons remain management-only. Direct client writes are denied. Properties with assignment history cannot change organization. Registration grants no general work-order/property/contractor or permit reads; future entry operations will check this exact property assignment.

Rolled-back SQL proves approval/verified identity, foreign property/account isolation, retry/audit deduplication, duplicate property assignment, stale revision, client-write denial, own-state/internal-audit privacy, self-management denial, deactivation, immutable trusted property binding, property-organization guard, unverified activation rejection and unverified read denial. Fixtures rolled back. Security advisors: no WARN/ERROR and existing 10 INFO intentionally closed tables ([reference](https://supabase.com/docs/guides/database/database-linter?lint=0008_rls_enabled_no_policy)). Security register API/UI, identity-checked property entry/check-out, signed-in/concurrency acceptance, evidence/completion/notices remain unfinished. No actual staff or access assigned. No web changes/build repetition.


### Property security assignment API

Added manager/admin-only `POST /api/staff/security-assignments`, with current verified access, origin/JSON/5000-byte body guards, approved property/email creation, revisioned active-state updates and mandatory approval/reason. Existing property/account inputs are rejected on updates; actor/organization/user inputs are stripped. Database checks derive organization/identity and verify current account/property authority. Permission and conflict errors return safe messages.

Focused API checks prove management access, origin/body bounds, create/reference/approval/revision validation, immutable account/property updates, normalized email and authority stripping, and safe stale/duplicate errors. TypeScript and production build pass. Management security register/history UI, property-scoped security entry/check-out, signed-in/concurrent acceptance and evidence/completion/notices remain open. No production security assignments created.


### Property security management register

Managed property detail now links to `/staff/security/[propertyId]`, restricted to verified manager/admin membership and the selected organization property. The register counts before 25-row reads and approves existing verified account emails for that property. Exact assignment detail checks organization, protects immutable identity/property, supports activation/deactivation and pages internal actor/reason/previous/new active-state decisions independently. Forms require fresh approval/reason and retain stable unchanged retry IDs before navigating to their exact saved record. Security identities gain no internal audit/property/work data through these management screens.

Rendered page/form checks pass for role-before-read, property/register/history scope, missing records, pagination, fixed identity and fresh approval. Security/inventory API regressions, TypeScript and production build pass. Signed-in and actual concurrency acceptance, property-scoped security check-in/out, evidence/completion/notices and launch remain open. No real security accounts assigned.


### Independent security contractor presence database engine

Applied `20261007063846_contractor_security_presence`. An active verified security account assigned to the exact property can record entry only after an explicit identity-check attestation and while the approved permit/confirmed visit window is current, contractor registration is active/verified and work is scheduled. Self-entry is denied even for dual contractor/security accounts. The database derives binding, actor, organization and timestamps; organization locking rechecks security authority. Entry moves work to on-site, and departure moves it to in-progress, preserving work/offer revisions and presence audits. Departure remains available after permit revocation/expiry, subject to current assigned security and on-site work. One presence record per visit prevents duplicate entry. Identical retries return original outcomes. Internal work data remains unavailable to security; property-specific presence/audits are readable, while contractors read own presence without operational reasons.

Rolled-back tests prove unassigned management bypass denial, early entry rejection, identity-check requirement, independent dual-role self-entry rejection, arrival/time/work transition, retry/audit deduplication, stale departure, contractor private presence/internal-audit denial and self-departure rejection, revocation while on-site with successful independent exit, departure/time/in-progress transition and retry, and foreign-manager isolation. Fixtures roll back; no real entry recorded. Security advisors remain no WARN/ERROR and existing 10 INFO intentionally closed tables ([reference](https://supabase.com/docs/guides/database/database-linter?lint=0008_rls_enabled_no_policy)). Gatehouse lookup/API/UI/history, identity workflow browser acceptance, actual simultaneous entry/revocation proof, evidence/completion/notices and launch remain open. Identity attestation records staff confirmation; it does not independently validate an identity document or automate physical access. No web changes/build repetition.


### Security presence API — October 7

Added verified-account POST /api/security/presence for arrival and departure. The database RPC derives property security authority, actor identity and timestamps. Requests cannot inject these fields. Arrival requires an identity-check attestation and permit reference; departure requires the current presence revision. Origin, JSON and 5 KB body guards apply; database failures return safe permission/conflict messages. Focused API checks and TypeScript checks passed. The database engine passed the previous rolled-back fixture checks. Gatehouse lookup/screens and signed-in acceptance remain open; no real arrivals or emails were recorded.


### Gatehouse permit lookup and screens — October 7

Applied security_gatehouse_permit_lookup, a narrow authenticated RPC which checks current verified property security assignment and excludes contractor self-access. It returns only approved company/job title, property name, approved instructions, permit window/state and presence status. Internal work descriptions, audit reasons and account/organization identifiers are omitted. Rolled-back database checks passed eligible arrival, departed state and foreign-access rejection. Security advisor reports no warnings/errors; ten informational notices concern deliberately closed tables.

Added /security permit lookup and /security/entry/[permitId] with current arrival eligibility, a fresh identity attestation, server-recorded time, and departure after permit revocation. Contractor entry authorization now displays the permit reference for property security. Focused page/form checks and TypeScript validation passed. Full signed-in browser acceptance and concurrent-session proof remain open. No genuine permit, arrival or message was created during testing.

Gatehouse production build and entry-permit regression checks passed. The local preview has not yet been restarted onto this build.


### Presence history screens — October 7

Management work-order presence history verifies the organization and selected work order before querying visit-bound presence records. Selected event history requires that same parent binding. Security history requires a current verified account and an active assignment to the presence property before loading internal event notes. Both event views count before fetching, redirect excessive page numbers, and show at most 25 rows. History links were added to the work-order detail and gatehouse entry screen. Focused tests passed parent binding, current property coverage, audit filters, pagination, sign-in denial and unavailable-event handling. TypeScript validation passed. Full signed-in Data API/browser acceptance remains pending.

Presence history production build, security-presence suite and work-order regressions passed. Local production preview restarted on port 3001 with this build; HTTP checks confirmed signed-out security lookup, security history and management presence history redirect to sign-in. Signed-in browser/Data API checks remain open.


### Contractor completion report database — October 7

Applied contractor_completion_reports. Verified active assigned contractors can submit immutable work summary, tests and outstanding-item snapshots after security has recorded departure. Managers in the same organization can request changes with an explicit contractor-visible message or approve after attesting that evidence was reviewed. Contractor self-approval is rejected even when the account also holds a management role. Internal audit reasons remain management-only; security receives no completion-report access. Exact retries are idempotent and changed retries/stale reviews are rejected.

Approval atomically marks the work completed, sets the server completion time, closes confirmed visits (which revokes remaining permits), and completes the contractor assignment. Every transition advances the work/offer revisions and records attributable audit events. Rolled-back fixtures passed submission, requested changes, new immutable resubmission, approval, exact retries, changed retry rejection, stale review, missing approval attestation, self/dual-role denial, on-site submission denial, direct/trusted snapshot rewrite denial, foreign organization isolation and security privacy. No genuine work was marked complete. Security advisor has no warnings/errors; ten informational notices concern deliberately closed tables.

This is the database engine only. Completion API/screens, private photo/document attachments, corrections requiring another site visit, notifications and signed-in/concurrent acceptance remain unfinished. Narrative reports alone do not complete the evidence module.


### Completion report API — October 7

Added POST /api/completion-reports for contractor submission, management requests for changes and management approval. Verified-account access, same-origin JSON requests and a 16 KB body limit apply. Strict validation separates immutable submission fields from review fields, bounds revisions/text and requires fresh evidence review confirmation for approval. Caller-provided organization, contractor and completion-time fields never reach the RPC. Database authority remains decisive for ownership, organization, independent review and recorded departure. Safe permission/conflict errors do not expose internal database details. Focused API checks passed. Completion screens and private attachment workflow remain unfinished.

Completion submission/review form components are implemented and pass focused rendering checks for field separation, required text and fresh approval. TypeScript checks pass. Components still need integration into contractor and management report pages. API production build passed; these subsequently added form components are typechecked but await a build with their page integration.


### Completion report pages — October 7

Connected completion editors to contractor assignment completion pages and management work-order completion queues. Contractor reads use explicit own-account registration, assignment and report ownership filters; submission requires an accepted assignment, a latest recorded departure and no report awaiting review. Reports and shared management feedback are displayed in 25-row count-first pages. Management reads verify the organization work order before counting reports or loading a selected report bound to that work order. Request-change/approval forms are shown only for submitted reports on in-progress work and an independent reviewer. Links are provided from assignment and work-order details.

Focused page checks passed ownership/work-order scope, bounded reads, pending/departure submission gates, self/closed review denial and excessive-page redirects. TypeScript checks passed. Private event-audit history, photo/document attachments, return visits for corrections and signed-in Data API/browser acceptance remain open; these narrative screens do not complete the full evidence module.

Completion suite, work-offer/work-order regressions and production build passed. Preview restarted on port 3001; HTTP checks confirmed both completion pages redirect signed-out users to sign-in and the completion API returns 401. Signed-in acceptance remains pending.


### Private completion audit page — October 7

Added management-only report event history linked from report review. The page verifies organization access to the work order and then the report’s work-order/organization binding before querying internal event reasons. Counts precede 25-row reads; excessive page numbers redirect, count failures stop the read and event failures show a refresh message. Focused checks passed management/invalid-reference denial, missing parent/report denial, report/audit filters, page bounds and count/event failure handling. TypeScript checks passed. Contractor shared review screens do not include internal audit reasons. Signed-in acceptance remains pending; private evidence attachments and return-visit corrections are next.

Completion regression suite and production build passed for the private audit increment. The preview has not yet been restarted onto this audit build; signed-in audit acceptance remains pending.


### Private contractor evidence database/storage — October 7

Applied private_contractor_evidence and contractor_evidence_service_guards. A private bucket accepts PDF/JPEG/PNG up to 8 MB. Verified active assigned contractors can reserve files while work is on site/in progress and no completion report is pending. Reservations are retry-safe, expire after 30 minutes and enforce ten live files per assignment/fifty attempts per account per day. Client overwrite/removal policies are absent; only the trusted server can certify retrieved bytes/format/hash. The initial service-role fixture caught a missing helper execute grant; a corrective migration fixed it and adds strict assignment/identity binding for report evidence references.

Each completion submission freezes references to all verified uploaded files for its assignment. Referenced evidence cannot be withdrawn or have certified bytes rewritten; new report submissions retain those references. Contractors can read their own records; verified organization managers read uploaded evidence; reserved files stay private to the contractor. Security and foreign managers cannot read evidence or report links. No server credential was exposed.

Rolled-back tests passed reservation/exact retries, changed-request rejection, client certification denial, service certification/exact retries, reserved object metadata insertion and read, unreserved-path rejection, reserved manager privacy, manager uploaded reads, report reference freezing, withdrawal denial after requested changes, foreign isolation and security denial. Tests use transaction-only synthetic storage metadata/hash values; they do not prove actual file transfer, format screening or Storage service token behavior. No genuine file was uploaded or certified. Evidence API/UI, expired-orphan cleanup and signed-in end-to-end acceptance remain unfinished.


### Contractor evidence API — October 7

Added /api/contractor-evidence using the private contractor bucket and database reservation/freeze rules. POST supports reservation, trusted-server certification and withdrawal. Verified account, same origin, JSON and 4 KB request bounds apply. Reservations derive the Storage path from the database and issue non-upserting upload tokens. Missing/unconfigured server certification credentials stop reservation/finish with a configuration response before new uploads are prepared. Withdrawal is still possible without the server secret, subject to database stage/frozen-reference checks.

Finalization reads the own-account file through Storage RLS, checks actual size and basic PDF/JPEG/PNG format, computes SHA-256 on the server and supplies the verified actor to the service-only certification RPC. Caller paths, hashes and actor claims are ignored. GET uses uploaded-record RLS and prepares a 120-second download URL with no-store responses. Format checks do not prove file authenticity or malware scanning.

Focused API checks passed account/origin/credential/size/type/name guards, database paths, no upsert, server actor/hash, rejected formats/sizes/unavailable downloads, short-lived downloads, safe conflicts and withdrawal without server credentials. TypeScript checks passed. Upload/download screens, orphan cleanup and real Storage transfer acceptance remain pending; SUPABASE_SECRET_KEY is still missing.

Contractor evidence API, shared document/cleanup regressions, TypeScript and production build passed. Preview has not been restarted onto this API increment. Real file transfer and certification remain pending secure server credentials and signed-in acceptance.


### Contractor evidence screens and report attachments — October 7

Added contractor assignment evidence pages and private upload/finish/withdraw/download controls. Explicit registration/assignment/file ownership filters apply, with count-first 25-row pages and a one-row embedded reference limit to identify frozen files. Pending reports/completed assignments hide editing; frozen files have no withdrawal action, expired reservations have no finish action, and missing server credentials show configuration status instead of an upload form. Withdrawal of unfrozen evidence remains possible without the server secret. The component keeps a stable request ID for retries of the same selected file and retains the evidence reference when certification fails after transfer. Upload interruption offers retry/manual finishing rather than reporting success.

Management report review now loads only verified uploaded evidence bound to that report and organization, with a bounded eleven-row guard for the ten-file limit. These attachments are read-only. Contractor assignment/completion pages link to evidence management and explain that submission freezes all verified uploaded files. Focused page/UI checks passed assignment/file ownership, embedded reference bounds, pagination, pending/completed edit gates, frozen/read-only controls, expiry and missing configuration behavior. TypeScript checks passed. Signed-in browser/Storage transfer acceptance, orphan cleanup and return-visit corrections remain unfinished.

Evidence API/page/UI suite, completion/work-offer regressions, TypeScript and production build passed. Preview restarted on port 3001. HTTP checks confirmed the evidence page redirects signed-out visitors to sign-in and evidence GET/POST return 401. Signed-in upload/download and report-attachment acceptance remain pending.


### Contractor evidence expiry cleanup — October 7

Applied contractor_evidence_cleanup and added /api/jobs/contractor-evidence. Service-only claims select at most twenty unpurged reserved/expired/withdrawn files after reservation expiry plus two hours five minutes, beyond the latest issued upload token. Uploaded evidence and all report-linked evidence are excluded. Expired reservations receive one system event with no human actor attribution. Subsequent claims can retry failed removals without duplicating expiry events; purged files are excluded.

The worker requires a timing-safe CRON_SECRET check and a server database credential. It removes only claimed contractor-bucket paths and records purged_at only after Storage succeeds. Storage failure yields a retryable failure and no purge marker. Rolled-back metadata checks passed service-only access, timing/state exclusions, system expiry event, repeated claims and purged exclusion; worker checks passed authentication/configuration and failed-removal handling. TypeScript checks passed. No actual file was removed. Scheduling, real Storage removal and concurrent worker acceptance remain pending credentials/deployment; uploaded-file retention policy is not inferred from orphan cleanup.

Evidence regression suite, cleanup worker checks, TypeScript and production build passed. Security advisor reports no warnings/errors (ten informational notices for intentionally closed tables). Cleanup is implemented but not scheduled or exercised against actual files; the preview has not been restarted onto this worker increment.


### Contractor return-visit database transition — October 7, 2026

Applied `20261007071809_contractor_return_visit.sql`. Independent verified organization management can approve a return visit against a changes-requested report, with exact report/offer/work revisions and a private audit reason. The organization lock serializes this action with report submission/review and presence updates. Accepted coherent active contractor assignment, recorded departure and no pending report/proposal/on-site presence are required. Old departed confirmed appointments close (revoking any surviving permit); work returns to assigned with its schedule cleared and the offer revision advanced. Reports, frozen evidence and presence history are preserved. New scheduling reuses the existing proposal/confirmation and entry-permit workflow.

`verify-contractor-return-visit.sql` passed remotely in a rolled-back fixture: missing approval, stale report, contractor/foreign manager denial, successful transition, exact retry/changed nonce protection, preserved historical records, fresh proposal/confirmation and denied completion before the new visit. No real work order changed. Actual multi-session races and signed-in acceptance remain open. API/forms and broader return-cycle tests are the next increment.


### Return-visit API — October 7, 2026

Implemented `POST /api/contractor-return-visits` with verified organization management access, same-origin JSON enforcement, a 5 KB body bound, three exact integer revisions, explicit approval and a decision reason. Only the seven supported RPC arguments are forwarded; caller-supplied organization, actor and completion state are excluded. Database authorization/lifecycle checks remain authoritative. Focused mocked API checks cover unauthenticated/non-manager denial, invalid references/revisions/approval, trusted argument forwarding, no-store success, body bounds and safe conflict/error mapping. TypeScript passed. No real return visit requested. Management controls and signed-in acceptance remain pending.


### Return-visit management controls — October 7, 2026

Correction reports now provide an independent manager approval form when work is in progress and its accepted offer matches the current work revision. The offer lookup explicitly binds organization, work order and report offer; lookup failures stop rendering. Approval uses report/offer/work revisions and an internal reason, preserves the shared review and redirects to existing appointment proposals. Documentation-only corrections are explained separately. Database departure/pending-report/authority checks remain authoritative at submission.

Completion page regression checks passed for eligible correction controls, self-review exclusion, unavailable/closed/incoherent assignment states and exact offer scoping. Form checks passed for unchecked required approval, exact revision payload, same request ID across connection/server failures, conflict feedback and scheduling handoff. TypeScript passed in the implementation cycle. Signed-in browser acceptance remains pending; no actual correction appointment was created.


### Maintenance notification content — October 7, 2026

Added an allowlisted renderer for ten maintenance lifecycle notices: offers, appointments, entry changes, reports, correction feedback, approved completion and return visits. Emails contain an assignment/work reference and verified-account action path, excluding private addresses, evidence and entry instructions. Copy distinguishes offer review from acceptance, appointment confirmation from entry permission, report submission from completion and completion approval from payment. Focused content/reference/path checks passed. This renderer is not yet connected to database event capture/outbox claims; no maintenance notification was queued or sent. Next: immutable event snapshots, recipient/current-authority checks and stale-message supersession before worker delivery.


### Maintenance committed event snapshots — October 7, 2026

Applied `20261007072446_maintenance_notification_events.sql`. Private append-only event snapshots are created from committed offer, visit, permit, completion and return-visit audit inserts. Events carry organization/work/offer/contractor bindings, source identity/revision and current work/offer revisions, with a unique source preventing duplicate capture. Direct authenticated access and service updates/inserts are denied; the service can read snapshots for future delivery preparation. Emails, private descriptions and security instructions are excluded from these records.

Rolled-back remote fixture passed event capture for reports, change requests, new proposals/confirmation and return visits; exact retries produced one return event; entity/revision bindings and authenticated privacy/service immutability passed. Offer-created/closed and automatic permit changes still need focused coverage. No maintenance outbox message or real email was created. Next: current-event/recipient eligibility and delivery bridging.


### Maintenance notice eligibility — October 7, 2026

Applied `20261007072623_maintenance_notice_currency.sql`. Service-only eligibility checks bind event/work/offer/contractor identity and exact work/offer/source revisions, cap notices at seven days and require the current lifecycle state. Contractor-facing notices require an active verified account. Report-submission management notices remain independently eligible for review even when the contractor cannot receive email. Appointment and entry windows are checked; cancelled-visit and closed-offer notices are suppressed when replacement activity makes them misleading.

Rolled-back fixture passed current confirmed appointment eligibility, superseded proposal/report/correction/return-event denial, unknown-event denial, loss of contractor verification, expiry and authenticated execute denial. The attempted contractor deactivation fixture was corrected to assert the existing accepted-work guard instead of bypassing it. Full offer/permit/report-state coverage and delivery bridging remain open. No outbox email was created or sent.


### Maintenance durable outbox bridge — October 7, 2026

Applied `20261007072901_maintenance_outbox_bridge.sql` and narrow recipient helper correction `20261007072935_maintenance_notice_recipient.sql`. Service-only bounded pending-event reads and queue preparation now use unique event/outbox binding, organization serialization, current eligibility and database-derived recipient/workspace paths. Exact retries preserve the first stored message. The shared transactional claim and immediate pre-send check suppress stale events and changed contractor email addresses; legacy enquiry claims exclude maintenance messages. Broad access to auth.users was not granted: a service-only private helper resolves one eligible event recipient.

Rolled-back remote checks passed current event preparation, snapshot/path/organization/recipient binding, duplicate/rewrite prevention, transactional claim, pre-send eligibility, changed-email denial/supersession and authenticated RPC denial. No real message was queued or sent. Worker preparation integration and notification monitor family support remain next. Existing notification workflow database regressions and actual concurrent worker acceptance remain open.


### Maintenance worker preparation — October 7, 2026

The authenticated notification worker now reads up to twenty eligible maintenance events, renders allowlisted privacy-preserving content and queues each through the database service-only bridge before claiming shared outbox messages. Recipient, organization and action path remain database-derived; the worker passes only event identity and rendered subject/text. Preparation failures stop the run before claiming or sending, leaving durable records for the next authorized run. Existing provider idempotency, immediate current-attempt checks, completion tracking and verified delivery reconciliation are retained.

Notification suite passed preparation ordering, exact queue arguments, invalid event denial, preparation/queue failure preventing claims/sends, existing message-family sending, stale pre-send skipping and safe error responses. TypeScript passed. Scheduler/server credentials remain missing, so no real worker delivery ran. Maintenance monitor family support and broader database workflow regression/concurrency acceptance remain pending.


### Maintenance delivery monitor — October 7, 2026

Applied `20261007073109_maintenance_notification_monitor.sql`. Both staff monitor RPCs classify maintenance outbox records separately, permit the maintenance family filter and retain organization-scoped 25-row pagination/provider outcomes. The UI filter now includes maintenance without exposing recipients or message bodies. Rolled-back remote checks passed superseded maintenance filtering, page clamping, generic row privacy and foreign organization isolation. Notification suite and TypeScript passed. Live scheduler/provider delivery and broader event/concurrency acceptance remain open.


### Shared notification database regression — October 7, 2026

After the maintenance outbox/claim/monitor changes, sequential remote rolled-back suites passed: `verify-notification-monitor.sql`, `verify-resend-delivery.sql`, `verify-open-house-notifications.sql`, and `verify-cosigner-notifications.sql`. Covered proof includes organization totals/filter/pagination/privacy, retained early provider callbacks and complaint/bounce precedence, canonical snapshot retry stability, reservation/invitation supersession and anonymous/client worker denial. Fixtures were rolled back; no live message or production application was created. These checks do not replace actual simultaneous worker races, signed-in browser acceptance or real provider delivery.


### Maintenance offer/report notice lifecycle coverage — October 7, 2026

New rolled-back remote suites passed: `verify-maintenance-offer-notices.sql` and `verify-maintenance-report-notices.sql`. Offer checks cover one created event across retries, eligibility before acceptance, review suppression after acceptance, current withdrawal/expiry notices and suppression of a closed offer when replacement work is offered. Report checks cover current submitted-review notification, suppression after changes are requested, current correction feedback, approved completion eligibility and one completion event across exact approval retries. Existing contractor ownership, authority, assignment, departure and immutable-report assertions run in these fixtures too. No real business records or emails were created. Focused permit/appointment event coverage and actual simultaneous/signed-in/live delivery acceptance remain open.


### Appointment/permit notice coverage and replacement fix — October 7, 2026

`verify-maintenance-entry-notices.sql` exposed multiple eligible entry notices after permit replacement. Applied `20261007073638_maintenance_entry_notice_order.sql`: database-generated event ordering now makes every newer entry update supersede older entry notices for the assignment. The captured-event table was confirmed empty before rollout; no historical ordering was inferred. Ordering works when multiple changes share the same transaction timestamp.

The rolled-back remote suite now passes proposal/confirmation capture and exact retries, old proposal suppression, permit approval/revocation/replacement eligibility, one current entry notice, cancellation suppressing old confirmation/permit messages and replacement appointments suppressing the cancellation notice. Existing scheduling overlap, permission, permit immutability and automatic revocation checks also passed. No actual appointment or email was created. Concurrent/signed-in/live delivery acceptance remains open.


### Finance journal input foundation — October 7, 2026

Added exact JMD minor-unit journal validation: two to two hundred lines, exactly one positive debit/credit per line, bounded safe-integer line amounts, account/property/unit reference shape checks, balanced BigInt totals, explicit posting approval and reason. Input authority fields are excluded; database authorization/account/dimension binding must still be implemented before exposing posting. Focused tests passed one-cent imbalance, fractional/string/negative/unsafe amounts, malformed dimensions, approval omission and balanced totals beyond Number-safe aggregate precision. TypeScript passed. This module is not connected to a posting API, database journal or payment provider; no financial entry was posted. Next: immutable organization-scoped journal storage and atomic balanced posting.


### Immutable finance journal database foundation — October 7, 2026

Applied `20261007074022_immutable_finance_journals.sql` and trigger record correction `20261007074147_finance_balance_trigger_record.sql`. Organization accounts require verified administrator approval; journal authority is restricted to verified admin/finance staff. Accounts, journals and lines reject update/delete and have no direct client/service write grants. Lines bind accounts/property/unit to the journal organization; integer minor amounts and deferred positive balanced two-to-two-hundred-line constraints protect storage. Database posting metadata is derived internally. Header transaction identity restricts line additions to the creation transaction; actual post-commit/multi-session proof remains open.

Rolled-back remote checks passed balanced posting, empty/one-cent-imbalanced denial at constraint validation, foreign account denial, immutable records, server timestamps/transaction metadata, finance read scoping, direct write denial, manager/foreign/unverified isolation. A shared trigger field-resolution issue caught by the first run was fixed and the suite rerun successfully. No real financial entry or chart was created. Approved account authoring and atomic journal RPC/API/UI are next; payments, reversals, billing/statement and provider policy work remain unfinished.


### Approved finance account authoring — October 7, 2026

Applied `20261007074311_approved_finance_account_authoring.sql`. Verified organization administrators can create immutable approved chart accounts through a scoped, serialized RPC; case-normalized codes prevent duplicates. Exact retries return the existing account; changed request payloads fail. A private organization-readable immutable approval record preserves actor/request/content. Finance staff can read their chart and approvals but cannot create them; managers/foreign/unverified accounts are restricted. Rolled-back database checks passed these approval, normalization, retry, isolation and audit immutability requirements. No actual chart account was created. Account API/register UI and atomic journal posting remain next.


### Finance account API — October 7, 2026

Implemented administrator-only `POST /api/staff/finance-accounts` with verified account/membership access, same-origin JSON checks, a 5 KB body bound, canonical account codes, approved classification/name/reason and explicit approval. Only supported RPC arguments are forwarded; organization/approver/timestamps remain database-derived. Focused API checks passed authority exclusion, invalid approval/code/classification denial, access guards, bounds and safe conflict handling. TypeScript passed. No actual account was created; account register/approval UI and atomic journal posting remain next.


### Finance account register UI — October 7, 2026

Implemented `/staff/finance/accounts` with organization-scoped count-first pagination, administrator-only approval form and a read-only finance staff view. Added an account navigation link. Explicit unchecked approval and bounded code/name/class/reason inputs accompany stable request identities for retries. Focused page checks passed organization scope, administrator/finance form gating, access denials, pagination clamping and database failure handling; rendered form checks passed required bounds and unchecked approval. Finance API/input regressions, TypeScript and the production build passed. No actual account was created; signed-in acceptance and atomic journal posting remain next.


### Atomic finance posting database — October 7, 2026

Applied `20261007075152_atomic_finance_posting.sql`. Verified admin/finance staff can post approved JMD journals through a single transaction. The function derives organization and actor, serializes organization changes, normalizes supported fields, checks 2–200 lines, numeric integer minor-unit limits and positive balanced totals, and verifies approved account/property/unit ownership. Property/unit rows are share-locked during validation. Exact actor/request/content retries return the original journal; changed payloads fail. Headers and lines insert atomically with existing immutable storage and deferred database balance enforcement.

Rolled-back remote tests passed balanced posting, exact retries, changed nonce denial, explicit approval, fractional/string amount denial, imbalance, missing/foreign account denial, manager/unverified access denial, scoped reads and no records after failed submissions. No real journal was posted. Journal API/UI, property/unit historical binding protection, multi-session/post-commit checks, reversal workflow, billing and statements remain open.


### Finance journal posting API — October 7, 2026

Implemented verified admin/finance-only `POST /api/staff/finance-journals`, same-origin JSON protection, an 80 KB byte bound and strict balanced JMD minor-unit input validation. Supported request/content/approval/line fields alone reach the atomic posting RPC; actor, organization, timestamps and client totals are excluded. Permission errors return 403, conflicts 409, invalid input 400 and unexpected database failures 503 so the client can retain its retry identity. Focused finance regressions and TypeScript passed, including approval/imbalance/fraction rejection, authority exclusion, safe error details and service-failure status. No actual journal was posted; posting UI and historical dimension protection remain next.


### Journal posting interface — October 7, 2026

Added verified admin/finance `/staff/finance/journals` and linked it from the approved account register. The form supports 2–200 stable-key lines, debit/credit selection, decimal JMD amounts, optional property/unit references, live exact balance comparison, memo/reason and explicit unchecked approval. Exact decimal parsing uses BigInt rather than floating-point multiplication; totals render beyond safe-number range. Stable request identity survives server/network failures; fields disable during posting and successful submission resets the captured form element. The current interface uses references from the account/property registers; searchable selectors and a journal history/detail view remain needed.

Finance regressions, currency boundary/format checks, initial rendered-form approval/line checks and TypeScript passed. Interactive retry/reset/browser and signed-in acceptance remain unverified. No real journal was posted. Production build is in progress at this checkpoint.


### Journal history and detail — October 7, 2026

Added organization-scoped count-first 25-row journal history and exact journal detail with separately scoped ordered lines, immutable account labels, decision/actor/request/time references and BigInt totals. Posting success navigates to its returned journal detail. Missing or foreign journal headers fail before line lookup; incomplete/error line reads fail instead of showing partial totals. Focused page/detail checks and TypeScript passed. Earlier posting-interface production build completed successfully; this history/detail increment still needs its own build and signed-in/browser verification.


### Journal form interaction verification — October 7, 2026

Added a hook-driven submission verifier covering exact decimal-to-cent payload, same request identity on network/503 retries, conflict reset, new identity for changed content, local denial of missing approval/unbalanced amounts without an API call, and successful detail navigation/form reset. All finance suites passed. These checks execute the component handler with mocked browser/fetch/hooks; they do not establish signed-in browser/database acceptance. The full journal history/detail production build passed, including TypeScript and page generation.


### Searchable journal accounts — October 7, 2026

Added verified admin/finance account-search API with organization-derived scope, literal code/name filters, 26-row probe/25-result cap and minimal account fields. Journal lines now use a code/name search and explicit selection rather than manual account UUID entry. Clearing changes the line reference; generation checks discard responses after search changes/selections. Safe loading, no-match, refinement and failure messages are included. Focused API checks passed verified access, organization scope, wildcard escaping, field/term bounds, result limits and safe errors. Existing finance handler/page/form regressions and TypeScript passed. Picker interaction/browser acceptance and current build remain unverified. Property/unit selectors and historical dimension protections remain open.


### Approved account picker interaction verification — October 7, 2026

Added hook-driven picker checks for stale response rejection after query changes, newer results surviving delayed older responses, code/name switch, explicit account selection/clear, result refinement, no matches and error recovery. All finance regressions passed. These checks use mocked fetch/hooks and do not replace signed-in browser acceptance. The account-selector production build passed compilation, TypeScript and page generation. Existing inventory guards protect units referenced by maintenance work orders; finance-specific historical parent/organization protection remains required.


### Journal dimension history protection — October 7, 2026

Applied `20261007080210_finance_dimension_history.sql`. Database triggers prevent changing a journal-linked property’s organization or a journal-linked unit’s parent property, preserving the immutable financial association. Descriptive property names/unit labels remain editable; unrelated properties retain existing update behavior. Rolled-back remote checks passed valid dimension posting, balanced constraint enforcement, both reassignment denials and permitted descriptive/unreferenced edits. No actual financial record was created. Concurrent transaction and post-commit proofs remain open; property/unit selectors and reversal workflow remain next.


### Narrow finance property/unit search database — October 7, 2026

Applied `20261007080356_finance_dimension_search.sql`. Verified admin/finance callers can search organization property names or unit labels bound to an organization-owned property through a narrow ID/label-only function. Literal wildcard escaping, 120-character bounds, 26-row probe/25-item response and safe parent validation are enforced in the database. Existing broad inventory RLS remains closed to finance. Rolled-back remote checks passed minimal fields, property/unit results, literal wildcard treatment, missing/unknown/foreign parent rejection, cross-organization isolation and manager denial. The application search API and journal property/unit picker remain next; this database function alone does not complete the selector experience.


### Journal property/unit picker API and UI — October 7, 2026

Connected the narrow dimension-search RPC through verified admin/finance GET `/api/staff/finance-dimensions`. Kind, term and unit parent UUID are validated; property searches discard submitted parent/authority fields, errors expose safe messages and responses are private/no-store. Journal lines now search property names and property-bound unit labels instead of manual references. Property changes/clear reset unit selection; keyed unit picker remount and unmount generation cleanup discard old responses. Search loading, refinement, empty, selection/clear and failure feedback are included. Focused API checks, finance regressions and TypeScript passed. Dimension picker handler/browser acceptance and current build remain open; concurrency and reversal workflows remain next.


### Property/unit picker interaction verification — October 7, 2026

Added hook-driven unit-picker checks for parent-required search, parent ID query binding, private/no-store requests, stale results after query edits, selection/clear, refinement, empty results, error recovery and unmount response rejection. Extended journal-handler checks prove property change/clear resets the old unit and keys the unit picker to its parent. Finance regressions passed. The first test run used an incorrect assumption about JSX text-node shape; the verifier was corrected and rerun. Signed-in browser/database acceptance remains open. Production build passed compilation, TypeScript and page generation.


### Approved journal reversal database — October 7, 2026

Applied `20261007080755_approved_finance_reversals.sql`. Verified finance/admin staff can explicitly approve a reasoned reversal that creates a new immutable balanced journal with original accounts/dimensions and opposite debit/credit amounts. An immutable organization-scoped link records original/reversal, actor, request and reason; unique original/reversal constraints prevent double reversal and reversal chains. The function serializes organization posting and derives all lines from the original, preserving it. Exact retry returns the existing reversal; changed request content or posting-nonce reuse fails. Rolled-back remote checks passed opposite line amounts, retry deduplication, duplicate/chain/approval/changed-nonce rejection, foreign denial and link immutability. No actual reversal was created. Reversal API/UI, transaction-concurrency proof and operational acceptance remain open.


### Journal reversal API and approval interface — October 7, 2026

Added verified admin/finance POST `/api/staff/finance-reversals` with same-origin JSON guards, 5 KB byte bound, strict request/journal UUIDs, reason and explicit approval. Only canonical RPC inputs reach the reversal engine; safe permission/conflict/validation/503 errors preserve useful retry behavior. Journal details now query organization-scoped original/reversal links, fail on missing history reads, show the linked opposite record and expose a reasoned unchecked approval form only for unreversed original journals. The form keeps its request identity across network/server failures and navigates to the returned reversal. Focused API and existing detail checks passed; TypeScript passed. Form interaction, reversal-state page gating tests, current build and signed-in acceptance remain open. No actual journal reversal was made.


### Reversal interaction and detail-state verification — October 7, 2026

Added rendered-form/handler checks for unchecked required approval, bounded reason, canonical journal payload, network/503 retry identity, conflict reset, changed-content identity and reversal-detail navigation. Extended detail-page checks verify unreversed originals expose the approval form, reversed originals link to their reversal without a second form, reversal records link back to the original without a reversal action, and reversal-history read failures stop rendering. Focused checks, the full finance regressions and production build passed, including TypeScript and page generation. These mock handler/page checks do not establish signed-in browser/database acceptance. No live reversal was created.


### Finance account statement database — October 7, 2026

Applied `20261007081144_finance_account_statements.sql`. Verified admin/finance can request an organization-owned account statement for up to 367 inclusive Jamaica calendar days. A stable function returns exact opening debit-minus-credit balance, period debits/credits, closing balance and 25 ordered line entries with running balances, journal IDs/memos and statement time. Numeric sums serialize as strings to preserve precision; page clamps to available results. Statement reads include all posted journal lines, including opposite reversal entries. This is an internal account statement, not a tenant bill or payment receipt.

Rolled-back remote checks passed 30-posting second-page totals/running balances, credit sign, next-day opening balance/empty page clamping, date bounds/order and foreign/manager access denial. No actual journal was posted. Statement UI, large-total/time-boundary/reversal acceptance, billing policy/provider and multi-session verification remain open.


### Internal account statement interface — October 7, 2026

Added `/staff/finance/accounts/[accountId]` linked from the approved account register. Verified admin/finance staff receive date-filtered exact opening/debit/credit/closing balances, ordered entries with running balances and links to source journals. Jamaica month-to-date defaults and strict real-calendar/date-span validation run before the RPC. Pagination preserves dates and redirects to the database-clamped page; foreign/unauthorized and failed reads do not render a statement. The UI explains debit-minus-credit balance signs. Focused tests passed invalid dates/ranges, large exact balances, canonical RPC fields, authority exclusion, paging and denied/failure paths; TypeScript passed. Current build and signed-in statement acceptance, reversal/date-boundary/large-total SQL regressions remain open. This internal statement does not establish billing or payment receipt completion.


### Large statement and reversal regression — October 7, 2026

Extended the rolled-back statement fixture with 200-line maximum-amount posting and matching reversal. Database totals remain exact string values beyond JavaScript safe-number range; final-page running balance agrees with closing balance before/after reversal, and the account returns to its prior 300030-cent balance while retaining debit/credit history. A mistaken expected arithmetic total in the first test was corrected; the suite then passed. All application finance regressions passed. Statement production build passed compilation, TypeScript and page generation; actual Jamaica-midnight boundary and signed-in/concurrent acceptance remain unproven. No real posting or reversal was created.


### Isolated local finance database verification — October 7, 2026

Created a temporary PostgreSQL 14 test cluster at `/private/tmp/openhouse-finance-pg`, local Unix socket `/private/tmp/openhouse-finance-socket`, port 55439, with no TCP listener. Added a minimal local bootstrap schema in `scripts/sql/finance-local-bootstrap.sql` and loaded the unchanged finance storage/account/posting/dimension-history/reversal/statement migrations. Posting, reversal and statement rolled-back fixtures passed locally. Initial sandbox shared-memory setup failed; elevated isolated-local setup succeeded. This runtime enables actual independent-session and post-commit checks without live financial records. PostgreSQL 14 evidence supplements Supabase PostgreSQL 17 checks and does not establish version-identical production concurrency acceptance. Concurrent fixtures remain next; the local server is running for that work.


### Actual local finance transaction concurrency — October 7, 2026

Added `scripts/verify-finance-concurrency.py`, hardwired to the isolated local Unix socket rather than remote credentials. It clones the loaded local finance schema into a temporary database, commits fixture records, runs independent psql sessions and explicitly observes advisory-lock wait contention. Concurrent same-request journal posting yields one journal/two lines; concurrent same-request reversal yields one reversal link and one opposite journal. A later transaction’s balanced pair append to the committed original is rejected by the journal transaction-binding guard. The test passed and removed its cloned database in a finally block. This establishes actual PostgreSQL 14 session/post-commit behavior, not version-identical Supabase PostgreSQL 17 concurrency acceptance. Property/unit update races and different-request duplicate reversal concurrency remain additional checks. The base local server stays running for these checks.


### Finance resource and competing-reversal races — October 7, 2026

Extended the actual local independent-session verifier. Different request IDs racing to reverse one original produce one link/opposite journal and one conflict. Property organization/unit parent updates explicitly wait behind posting-held share locks, then reject after the posting commits and history becomes visible. Conversely, an organization reassignment holding the row lock commits first; the waiting journal posting rechecks ownership, fails and inserts no journal. All observed-wait assertions passed on PostgreSQL 14. Each cloned fixture database was dropped; the base temporary server was stopped after verification. Supabase PostgreSQL 17 version-identical concurrency acceptance remains open. No live Supabase financial record was created.


### Posted-ledger trial balance database — October 7, 2026

Reviewed billing prerequisites: no approved signing/activation or billing rules are present, so billing remains dependent on those inputs; a concise provider/rules question is pending. Applied `20261007082039_finance_trial_balance.sql` for independent finance reconciliation. Verified admin/finance receive organization account net debit/credit balances through a Jamaica calendar date, exact string-valued organization totals, balance equality and 25-account pagination. Cutoff filtering includes reversal entries without changing original postings; stable reads share the request snapshot. Rolled-back checks passed current balanced totals, prior-day zero totals, page clamping, foreign empty results and manager denial, alongside statement/large-posting/reversal regressions. Trial-balance UI, large-total/pagination/reversal-specific assertions and signed-in acceptance remain open. No actual bill, payment or financial entry was created.


### Finance trial balance interface — October 7, 2026

Added verified admin/finance `/staff/finance/trial-balance`, linked from the account register. The page shows exact full-chart debit/credit totals, equality/investigation feedback, 25-account pagination, valid Jamaica through-date filtering and month-to-through account statement links. Organization authority stays server/database-derived; failed/unauthorized reads do not render balances. Focused page checks passed large exact totals, dates, canonical RPC arguments, pagination, imbalance alert and access/error paths; TypeScript passed. Current production build, broader SQL trial-balance assertions and signed-in acceptance remain open. Billing/provider/activation inputs remain pending.


### Trial balance full-chart precision and reversal verification — October 7, 2026

Expanded remote rolled-back trial-balance fixtures to assert exact string-valued debit/credit totals beyond JavaScript safe-number range, restoration of prior net balances after a maximum-amount reversal, and 29-account pagination with zero-balance approved accounts. The final four-account page preserves full-chart totals and clamps excessive pages. These checks passed alongside access/cutoff/statement fixtures. All test records were rolled back. Trial-balance production build and all finance regressions passed, including TypeScript and page generation. Signed-in browser and approved billing/activation inputs remain open.


### Role-aware account tool navigation — October 7, 2026

Replaced universally visible staff links on `/account` with a verified membership-based server component. Finance/admin access journals, accounts and trial balance; management access includes maintenance/contractor work; realtor/catalog, organization policy/template/team administration and security permit tools follow each route’s current role requirements. Unverified/nonstaff accounts receive no team-tool menu. This improves discoverability of built workflows without changing API/database authorization. Focused role/access navigation checks and TypeScript passed. Current build and signed-in UX acceptance remain open. Billing/signing/provider inputs remain pending; the broader production objective is active.


### Account dashboard loading — October 7, 2026

Role-aware navigation production build passed. Changed the verified account dashboard’s six independent Supabase reads (saves, enquiries, viewings, seller reviews, applications and co-signer invitations) from sequential awaits to one Promise.all. Existing user scopes, bounds and per-section returned-error feedback remain. A controlled-resolution verifier proves all six queries start before any resolves, unverified accounts issue none, owner filters remain and one returned section error leaves other section results renderable. Focused checks and TypeScript passed. A build of this loading increment and signed-in runtime performance acceptance remain open.


### Full regression and production build — October 7, 2026

Added `npm test` as the sequential aggregate runner for every existing `test:` group. All 33 groups passed, including finance, navigation and parallel account loading. The current production build compiled, typechecked and generated successfully. Local mocked/fixture checks remain distinct from authenticated browser, deployed storage/email, production concurrency and client acceptance. Updated the plan’s current queue and corrected an ambiguous historical finance sentence: signed-in browser verification remains open. The broader development goal remains active.


### Approved owner portfolio access foundation — October 7, 2026

Applied `20261007083154_approved_owner_property_access.sql`. Verified organization administrators can grant access to a specific managed property using an approved verified account email, explicitly approve a reason, revoke or reactivate with current revisions, and retry the same request safely. Organization/user/property bindings remain immutable; property organization moves are blocked once access history exists. Owners see their own register records; only administrators see internal approval reasons and audit. Direct API writes are denied, audit changes/deletion are blocked, and revoked grants do not reactivate when an old create request is replayed. Access approval does not claim legal title or an ownership percentage.

Remote rolled-back fixtures passed grant/retry/changed-request, foreign property, unverified identity, approval, stale version, direct-write, owner/manager/foreign-admin isolation, revocation/replay, binding protection and audit immutability checks. Input boundary/authority-exclusion tests and TypeScript passed. Security advisors reported only the existing 11 INFO closed-table notices, with no new owner access warning. No real owner was granted access. Owner administration API/UI, portfolio/report RPCs and signed-in acceptance remain unfinished and are the next owner workflow dependencies.


Owner access API increment — October 7, 2026: added administrator-only `/api/staff/owner-access` with same-origin JSON/body guards, strict approval and immutable-identity input, canonical RPC arguments, private no-store responses and safe authorization/conflict/retryable failure mapping. Focused handler and validation checks plus TypeScript passed. Authority is derived by the existing server/database checks; client organization/user/actor fields are excluded. Management forms, owner reports, current build and signed-in acceptance remain open.


Owner access administration screen — October 7, 2026: added property-bound administrator register with count-first 25-row pages, verified-email grants, current-revision activation/revocation, explicit unchecked approval and reasons, disabled in-flight controls, and stable retry request IDs. Managed property pages link administrators directly to each register; account team navigation exposes the owner access entry to administrators only. Focused server-page scope/pagination/denial/error checks, existing owner API/validation and navigation checks, plus TypeScript passed. Client form interaction, audit-history UI, portfolio reports, production build and signed-in acceptance remain open.


Owner access form interaction verification — October 7, 2026: hook-driven checks passed explicit unchecked approval/local denial before fetch, property-bound new grant, immutable identity on revocation, current version, stable request IDs after network/503 failures, conflict feedback/new request IDs, changed-content retries and successful register refresh. All owner validation/API/page/form groups passed. Production build is running; approval-history screens, owner portfolio reporting and signed-in acceptance remain open.


Owner approval history increment — October 7, 2026: the prior owner administration production build succeeded. Added administrator-only access-record history with current access state, immutable reasons, before/after approval snapshots, actor references and Jamaica times, count-first 25-row pages and canonical out-of-range redirects. Reads require the scoped parent access record and organization. Linked each register record to history. Focused history permission/scope/pagination/count-failure checks and all owner checks passed; TypeScript passed. The history increment itself still needs a build and signed-in acceptance; owner portfolio/reporting remains next.


Owner portfolio summary database increment — October 7, 2026: applied `20261007083909_owner_portfolio_summary.sql`. Fresh verified owners read only currently active property approvals through a private scoped report/public invoker RPC. The report paginates 25 properties and returns managed-unit/current-open-work counts plus exact string-valued property-attributed posted income/expense/net over bounded Jamaica dates. It exposes no internal reasons, actor identities, addresses, raw journals or organization IDs. Occupancy is explicitly unavailable until verified tenancy activation exists; posted financial activity is distinct from cash receipts/distributions. Rolled-back remote fixtures passed exact totals, day cutoffs, invalid ranges, page clamping, unrelated accounts, revocation and unverified denial. Security advisors remain the existing 11 INFO closed-table findings, with no new warning. No real business record was created. Report UI, multi-page/large-total/reversal assertions and signed-in acceptance remain next; the broader production objective remains active.


Owner portfolio interface — October 7, 2026: added verified-account `/account/portfolio` with bounded Jamaica date filters, exact large JMD amounts, approved-property pages, current unit/work-order counts, explicit posted-income/expense basis and occupancy-unavailable disclosure. Linked the account dashboard to the portfolio. The screen passes only dates/page to the owner-scoped RPC; user/organization authority remains database-derived. All owner checks, focused large-money/date/pagination/access/error/empty-state page checks, account regression and TypeScript passed. Production build, broader report SQL large-total/reversal/multi-page assertions and signed-in acceptance remain open.


Owner report precision, reversal and pagination verification — October 7, 2026: expanded and passed remote rolled-back report checks for 200 maximum-amount journal lines, exact income/net beyond JavaScript safe-number aggregation, restoration of prior net amounts after an approved reversal, 28 active approved properties split across 25/3 rows and excessive-page clamping. Revoking one property removes only that property; other approvals remain. All fixtures rolled back. Current production build is running (session 10444); signed-in report/administration acceptance, occupancy/activation and remaining broader platform work remain unfinished.


Owner reporting build and operational-count verification — October 7, 2026: the current production build passed compilation, TypeScript and page generation, including portfolio and access-history routes. Expanded remote rolled-back report fixtures prove managed-unit counts bind to the approved property and current-open-work counts exclude closed/cancelled jobs and foreign property records. Precision/reversal/pagination/access regressions remain passing. Owner access and posted-summary implementation is established; authenticated business acceptance, detailed reporting, verified occupancy and the full platform scope remain open. Next dependency-ready finance work is vendor invoice review and approval separation, with payment execution still gated on provider/business inputs.


Vendor invoice boundary foundation — October 7, 2026: inspected the closed legacy invoice schema and added strict submit/review/approve/reject input normalization. Intake requires positive exact JMD minor units, bounded vendor/invoice references, explicit attestation/reason and valid optional property/work bindings; review cannot alter submitted identity, amount or resource details. Client actor/organization/status/ledger fields are excluded. Focused boundary tests and TypeScript passed. No invoice is persisted or approved by this validator alone. Organization-bound revisioned invoice persistence, independent reviewer/approver transitions, audit, duplicate control, API/UI and payment evidence remain unfinished next steps. Payment execution and posting must not be inferred from approval.


Audited vendor invoice persistence — October 7, 2026: applied `20261007084602_audited_vendor_invoice_review.sql`. Added organization-scoped invoice/audit records with exact minor units, normalized vendor/number duplicate protection, immutable submitted details, property/work binding checks, retry-safe revisions and fresh role authority. Verified manager/admin/finance can submit; verified admin/finance independently review, and a third actor independently approves. Rejection closes an unapproved invoice; terminal approval is not ledger posting or payment. API direct writes remain denied and audit/property history is protected. Remote rolled-back checks passed intake/retry, duplicates, fractional cents, foreign properties, direct writes, role separation, required review, separate approver, stale revisions, audit/amount preservation, absent ledger posting and foreign/unverified isolation. Advisors remain the existing 11 INFO closed-table findings. No real invoice/payment was created. Invoice API/UI, attachment/payment evidence, additional rejection/retry/concurrency tests and signed-in acceptance remain unfinished. Business release must confirm the three-actor approval policy before operation.


Vendor invoice API increment — October 7, 2026: added `/api/staff/invoices` for verified admin/manager/finance intake and admin/finance review actions. Same-origin JSON, bounded body, strict canonical immutable inputs and explicit approval precede the scoped database RPC. Managers cannot call review/approval through this route; fresh database role/actor separation remains decisive. Responses are private/no-store with safe authorization/conflict/retryable errors. Focused API/validator tests and TypeScript passed. No real invoice was submitted. Intake/review/history screens, evidence, broader database transition/concurrency checks, business-policy confirmation, build and signed-in acceptance remain open.


Vendor invoice intake component — October 7, 2026: added approved vendor/number/amount/reason intake with optional server-selected property/work allocation, exact decimal-to-minor-unit parsing, explicit unchecked evidence attestation, disabled in-flight controls and stable retry IDs. Hook-driven checks passed invalid decimal/approval denial before fetch, exact cents and resource payload, network/503 retries, conflicts, changed amounts and successful detail navigation. All invoice checks and TypeScript passed. This component is not yet mounted in an invoice route; queue/detail/review/history screens must exist before navigation is operational. Evidence storage/payment execution and business policy/real-role acceptance remain unfinished.


Vendor invoice queue and detail routes — October 7, 2026: mounted intake at `/staff/finance/invoices` and added scoped invoice detail/history routes so successful submission has a destination. The queue filters before count-first 25-row pagination; detail reads bind parent and history to organization/invoice, show fixed amount/resource/actor references and audit reasons, and clamp pages. Added role-aware account navigation for admin/manager/finance. Existing invoice/navigation checks and TypeScript passed. Page-specific scope/error/pagination verification, review/approval controls, usable property/work allocation selection, build and signed-in acceptance remain unfinished. General intake currently creates organization invoices without a property allocation; no actual invoice was submitted.


Invoice review controls — October 7, 2026: connected invoice detail to explicit reasoned review/approval/rejection controls. Visible actions follow verified role, invoice state and actor separation: managers and submitters get none; submitted invoices allow independent finance review/rejection; a current reviewer cannot also approve; terminal invoices get none. The database independently rechecks all authority. Approval is unchecked, request IDs are stable across retryable failures and controls are disabled in flight. Role/actor/state/render checks, existing invoice checks and TypeScript passed. Hook-driven review interactions, page scope/error checks, allocation selection, evidence, build and signed-in acceptance remain open.


Invoice queue/detail verification — October 7, 2026: added and passed focused server-page checks for verified role gates, organization-bound parent/queue reads, invoice-bound audit reads, state filtering before count/pagination, 25-row ranges, empty/out-of-range canonicalization and auth/parent/count/row failures. Existing invoice validation/API/intake/action checks pass. These tests use controlled page dependencies; they do not establish authenticated browser acceptance. Review interaction retries, allocation selection, invoice evidence, current production build and full launch work remain open.


Invoice review interaction verification — October 7, 2026: hook-driven checks passed explicit approval and allowed-action denial before fetch, immutable current-version payload, network/503 retry identity, conflict feedback/new request IDs, changed decision IDs and successful refresh. All invoice test groups passed. Production build is running (session 16326); property/work selection, private evidence, broader SQL rejection/retry/concurrency checks, policy confirmation and authenticated acceptance remain open.


Invoice intake from managed resources — October 7, 2026: connected intake to approved managed-property pages for admin/manager and to work-order details. Work-order intake verifies the parent property with organization scope and derives both resource IDs from the selected records; the form cannot reassign allocation. Extended work-order page checks assert these bindings; work-order/API, invoice and TypeScript checks passed. Finance-only standalone searchable allocation, property-page focused acceptance, evidence and full authenticated acceptance remain open. The prior invoice production build remains live (session 16326); it does not include this newer resource integration.


Invoice build and allocation regression checkpoint — October 7, 2026: build session 16326 completed successfully (compilation, TypeScript and page generation). The build was started before the newest managed-resource form integration; it proves the invoice routes/review controls, while those subsequent edits have TypeScript and focused work-order/intake coverage. Extended intake checks now assert both work-order/property payload references and no fetch when a work order lacks its required property. Invoice/work-order suites and managed-inventory API regression passed. Finance-only standalone searchable allocation, private evidence, broader database transitions/concurrency and authenticated acceptance remain open. The full production goal remains active.


Finance invoice property selection — October 7, 2026: standalone admin/finance intake now uses the existing narrow organization-scoped property label picker; optional selection/clear changes the canonical allocation and retry identity. Fixed property/work forms retain their server-selected bindings. Managers receive a managed-record handoff instead of a finance-only search they cannot authorize. Focused stateful selection/clear payload assertions, all invoice checks and TypeScript passed. Existing search/RPC authority still applies without granting finance broad property access. Standalone finance work-order search, private invoice evidence, new-build and authenticated acceptance remain open.


Finance invoice work-order search database — October 7, 2026: applied `20261007085804_finance_invoice_work_search.sql`. Verified admin/finance search only within a required organization property through a private scoped helper/public invoker; results expose ID/title labels only, cap at 25 with a more-results flag and treat wildcard characters literally. Remote rolled-back tests passed result bounds/minimal disclosure, literal search, foreign/missing parent, search length and manager denial. No live record changed. Search API/picker and invoice selection/reset integration remain next; private evidence and full acceptance remain open.


Invoice work-order search API — October 7, 2026: added verified admin/finance GET `/api/staff/invoice-work-orders`, requiring a valid property UUID and bounded literal term before invoking the scoped search RPC. Authority fields are excluded; success and errors are private/no-store with safe denial/input/retryable errors. Focused API checks, all invoice checks and TypeScript passed. Work-order picker, property-change reset/stale-response integration, private evidence, build and authenticated acceptance remain open.


Invoice work-order picker integration — October 7, 2026: added selected-property work search with labels-only results, explicit selection/clear, error/loading feedback and in-flight response invalidation. Admin/finance intake binds optional work selection to the selected property; changing/clearing the property resets work and remounts the keyed picker to discard old responses. Fixed managed-record allocations remain fixed. Stateful intake tests passed work selection, new-parent reset, keyed remount and canonical payloads; invoice checks and TypeScript passed. Picker-specific stale-response/selection checks, private evidence, current build and authenticated acceptance remain open.


Invoice work picker verification — October 7, 2026: focused picker checks passed required-parent/no-fetch handling, scoped no-store search, stale query and unmounted-response rejection, result-cap feedback, selection/clear and empty/provider-error feedback. All invoice tests and TypeScript passed. Parent-change reset remains covered by stateful intake checks. Next invoice dependency is private source-document evidence with certification and approval-bound immutable references; live Storage acceptance remains credential-gated. Current build and broader signed-in production acceptance remain open.


Invoice evidence input foundation — October 7, 2026: inspected existing private document/contractor certification flows and added invoice/supporting evidence normalization using the shared PDF/JPEG/PNG 8 MB filename/format metadata bounds. Reservation references and finish/withdraw/download actions are validated; actor/organization/path/hash/state are excluded from client authority. Payment labels are not accepted as invoice evidence actions. Focused metadata/action/reference/spoofing checks, all invoice checks and TypeScript passed. This boundary alone does not reserve/upload/certify documents. Private invoice evidence schema/Storage policies, trusted certification, approval-bound snapshots, API/UI, cleanup and actual Storage acceptance remain unfinished next dependencies.

Private invoice evidence foundation (October 7, 2026): remote migration `20261007090320_private_invoice_evidence.sql` and rolled-back SQL verification passed private bucket constraints, scoped metadata reads, immutable identity and blocked direct writes. The bucket has no upload/read policy yet: this is a database foundation, not a usable upload feature. Certification RPCs, API/UI, approval-bound evidence snapshots and cleanup remain next. Security advisors returned the existing 11 informational closed-table notices only. No live invoice, attachment or email was created by verification.

Invoice evidence state verification (October 7, 2026): database transition guards and expanded rolled-back fixture passed certified hash/time immutability, no uploaded-to-reserved/expired transitions, and no withdrawn revival/timestamp edits. These guards protect metadata; actual file certification and approval snapshots remain pending. All nine invoice script groups and TypeScript passed this checkpoint.

Invoice attachment workflow checkpoint (October 7, 2026): scoped reservation/certification/withdrawal functions and private Storage policies are applied. A verified submitter can edit evidence only before review. The server derives file hashes after downloaded-byte size/format checks; browsers cannot certify files. Invoice detail now has gated private upload, verification, withdrawal and short-lived download controls. Remote rollback tests and all eleven invoice scripts plus TypeScript passed, including same-file retries and ambiguous transfer recovery. Production build session 73289 is running. Review snapshots/source-invoice requirements, cleanup, expanded concurrency/expiry/quota tests and actual authenticated Storage acceptance remain open. The missing server credential keeps uploads unavailable in the current product configuration.

Invoice review snapshot checkpoint (October 7, 2026): certified source documents are now required before review, active unfinished uploads block review, and the exact document identities/hashes/sizes are frozen for that review revision. Approval requires this snapshot; reviewed evidence cannot be withdrawn or marked purged. Remote rolled-back checks passed source/support/pending-upload denial, retry-stable snapshots, organization isolation and immutable evidence protection. Invoice detail reads frozen references, shows the reviewed revision and suppresses decisions when required evidence cannot load. Focused page tests and TypeScript passed. Build 73289 passed for the earlier upload interface; the updated suite/build is running in session 40573. Actual signed-in file transfer remains unverified and credential-gated; cleanup and broader workflow acceptance remain next. The full production objective remains active.

Invoice snapshot verification complete for this checkpoint (October 7, 2026): session 40573 passed all eleven invoice scripts and the current production build (compilation, TypeScript and page generation). Remote rollback tests passed pending-upload review denial and successful review after withdrawal, preserving the certified source snapshot. No build/test process remains live from this checkpoint. Cleanup, broader invoice boundary/concurrency tests, actual file transfer and wider launch gates remain unfinished. No production deployment was made.

Invoice cleanup checkpoint (October 7, 2026): database cleanup claims and `/api/jobs/invoice-evidence` are implemented. Removal waits beyond signed-upload lifetime, excludes current/reviewed evidence and uses expiring worker claims. Storage removal must succeed and object metadata must be absent before the database records a purge. Remote rollback checks passed exclusion, leases, retry markers, privileges, expiry audit and batch bounds; focused endpoint checks and TypeScript passed. The private claim table adds one expected informational no-policy notice, with direct grants revoked. No actual file deletion, scheduler activation or deployment occurred. Current suite/build and broader invoice boundaries are being verified next.

Invoice cleanup and boundary verification (October 7, 2026): remote rollback coverage passed independent current/daily upload caps, expiry handling and retry-safe terminal rejection. All twelve invoice scripts and the current production build passed in session 59240. Aggregate regression is running in session 80439. Actual provider file deletion, scheduled execution, multi-session invoice races and signed-in acceptance remain open.

Full regression checkpoint (October 7, 2026): session 80439 completed successfully with 35/35 verification groups, including the current owner and invoice modules. The current production build is also green. These are controlled implementation tests; actual signed-in/live-provider acceptance remains open. An isolated local PostgreSQL concurrency server could not start under the sandbox because shared-memory access was denied; no server was left running by that attempt.

Invoice concurrency evidence (October 7, 2026): isolated independent-session tests passed reservation deduplication, competing upload-cap denial, certification-before-review snapshots, review-before-withdrawal denial and exclusive cleanup claims. The script observes actual database wait states. This is local PostgreSQL 14.19 with simulated Storage metadata, not Supabase PostgreSQL 17 or actual file transfer acceptance. Its temporary test database was removed; the fixture server was stopped. Current full regression is 35/35 and production build is green. Wider production scope, business provider/rule inputs and live service credentials remain open.

Staff invitation foundation/API checkpoint (October 7, 2026): approved email-bound invitation storage, versioned create/revoke/accept/decline transitions and immutable invitation/membership history are implemented. Staff access is granted only after explicit acceptance by the matching verified recipient, with current inviter approval rechecked and existing access protected. Remote rolled-back checks passed authority/isolation/consent/retry/state boundaries. The API validates fixed-role replies and safe private failures; focused checks and TypeScript passed. No actual invitation, email or staff grant was made. Administrator/recipient pages, share controls, email worker integration and broader expiry/quota/concurrency/live acceptance remain next.


Staff invitation product checkpoint — October 7, 2026: administrators now have a scoped, paginated invitation queue, explicit approval/creation and revocation forms, and private immutable decision history. Verified recipients find email-bound invitations from their account and review organization, approved role, expiry and status before explicitly accepting or declining. The narrowly scoped `20261007095000_staff_invitation_summary.sql` RPC returns decision eligibility without exposing inviter identity or internal approval reasons; existing staff access, expired invitations and changed inviter approval suppress acceptance. Forms prevent duplicate in-flight submissions and preserve the request nonce for uncertain failures. API/page/access/pagination/unchecked-consent checks, membership/navigation/account regression and the production build passed. Remote rolled-back checks passed recipient summary isolation, stale approval and existing-member eligibility, expired acceptance denial, replacement/expiry auditing and identical replacement retry, the ten-per-administrator daily bound and the hundred-active-invitations organization bound. The expiry fixture initially expected a conflict code; the database correctly returned an authorization denial, and the fixture was corrected and passed. No real invitations or memberships were created. Transactional invitation email/outbox integration, actual concurrent acceptance races and signed-in acceptance remain open. Engineering quota/expiry defaults still require business agreement before live use; the overall production objective remains active.

Current regression checkpoint: all 36/36 verification groups passed after invitation screens and summary integration; production build passed. Next implementation loop: transactional invitation notifications and concurrent acceptance verification, followed by the remaining production milestones.


Staff invitation transactional delivery — October 7, 2026: applied `20261007095602_staff_invitation_notifications.sql`. Approved invitations atomically queue one organization-bound recipient message with fixed role/expiry text and a private account-review path, excluding internal approval reasons. The shared transactional claim snapshots the canonical HTTPS URL/sender once and preserves the invited email, sender and payload across retries. The older enquiry worker cannot claim link-dependent staff invitations. Closed/expired invitations, changed inviter approval and existing staff recipients are suppressed at claim and immediately-before-send checks. Accept/decline/revoke supersede pending/processing messages and revoke their leases. Administrator-only invitation rows and counts are enforced in both database monitors; non-admin staff receive no invitation delivery metadata. The monitor exposes the new family only to administrators. Invitation screens link to that monitor and explain incomplete worker configuration. Focused notification/invitation checks, TypeScript and the production build passed. Remote rolled-back delivery verification passed atomic retry deduplication, private payload boundaries, administrator/manager/foreign isolation, stable provider-retry snapshots, wrong-token denial, revocation/expiry/stale approval suppression, accept/decline closure and accepted-request retry after membership revocation without regranting access. Staff invitation/expiry quota, co-signer and maintenance outbox regression fixtures passed after integration. Fixture seeding was updated to supply the correct approved creator identity required by the new trigger. Security advisors remain at the same twelve informational intentionally closed-table findings; no new warning/error. Actual email delivery remains unverified and gated on the server credential, cron secret, production origin, signed Resend webhook and scheduler; no real messages, invitations, memberships or deployment were created.

Staff invitation concurrent admission — October 7, 2026: `scripts/verify-staff-invitation-concurrency.py` passed in a temporary local PostgreSQL 14.19 database over a Unix socket with no TCP listener. Observed independent sessions waited on organization advisory locks and Auth transaction locks. Identical creation/acceptance retries produced one invitation/grant/history; cross-organization invitations produced one membership without overwriting it; changed Auth email, prior direct membership grant and inviter revocation prevented acceptance. The fixture loads the admission/membership functions into a clone of minimal Auth/finance metadata; notification transport is separately verified in remote rolled-back fixtures. Its initially missing authenticated membership read grant was added only inside the clone. The clone was removed and the local fixture server stopped. PostgreSQL 17 version-identical concurrency, real signed-in onboarding and provider delivery remain open launch gates.


Cheque custody input foundation — October 7, 2026: reviewed the closed legacy cheque table and added strict receipt/action normalization for receive, deposit, clearance, return and cancellation. Receipt property/payer/bank/reference/JMD minor-unit details cannot change during later actions; current revisions and explicit approval/reasons are required. Bank actions require certified-evidence references and bounded bank references; cancellation cannot masquerade as a bank event. Client actor/organization/status/ledger authority is excluded. Focused validation checks and TypeScript passed. This boundary alone does not receive, deposit, clear, return, cancel or post any cheque. Audited schema/RPC, certified bank evidence, controlled accounting/reversal integration, API/UI, concurrency and live acceptance remain unfinished. Accounting and cheque policies remain business inputs. The production objective remains active.


Audited cheque custody foundation — October 7, 2026: applied `20261007100613_audited_cheque_custody.sql`. Verified organization admin/finance users can record exact JMD receipts and explicitly cancel a currently received cheque through versioned, idempotent RPCs. Receipt property/payer/bank/reference/amount/currency/actor/time are immutable; cancellation cannot revive. Receipt property organization is protected by history, and approval history cannot be edited/deleted. Client and service direct writes are closed. The legacy cheque table remains closed. This foundation intentionally exposes only receipt/cancellation until certified bank evidence and controlled accounting are connected; deposit/clear/return are still unfinished requirements, and custody creates no ledger journal. Database boundary verification is running. The production goal remains active.

Cheque custody remote rolled-back verification passed exact/change retries, normalized duplicate detection, foreign property/receipt denial, manager read/write denial, fractional-amount and premature-clearance rejection, approval/revision checks, cancellation retry, immutable identity/history, terminal-state protection, protected property organization and service direct-write denial. Journal counts stayed unchanged. No real cheque or ledger entry was created. Next: custody API/screens and private certified bank evidence, then audited bank transitions and approved accounting integration.


Cheque custody API checkpoint — October 7, 2026: added `/api/staff/cheques` with verified admin/finance access, same-origin bounded JSON, strict canonical receipt/cancellation input, explicit approval and private/no-store responses. Client organization/actor/status/journal fields never reach the RPC. Unsupported bank actions fail closed before a database call until certified evidence/transition integration is complete. Focused API checks passed access/origin/body/approval gates, canonical arguments, immutable cancellation details, unavailable bank-action denial and safe authorization/conflict/retryable error handling; TypeScript passed. Staff receipt/history screens, bank evidence, bank transitions, ledger/reversal integration and live acceptance remain unfinished. The production goal remains active.


Cheque custody screen checkpoint — October 7, 2026: added verified admin/finance-only `/staff/finance/cheques` with organization-scoped count-first 25-row receipt pages, exact JMD display, receipt form using the existing managed-property picker and version-bound cancellation controls. Approval is explicitly unchecked, duplicate in-flight submissions are blocked and ambiguous failures preserve the request nonce. Navigation exposes custody only to admin/finance. Cheque API/input checks, staff-navigation checks and TypeScript passed. Dedicated page/form interaction verification, private audit detail/history, certified bank evidence and controlled deposit/clear/return/accounting remain unfinished. No real cheque was recorded; the overall production objective remains active.


Cheque receipt audit screen — October 7, 2026: added `/staff/finance/cheques/[chequeId]` with verified admin/finance gating, UUID validation, organization-bound parent receipt, exact JMD and Jamaica timestamps, immutable property/receiver references, current-state cancellation and count-first parent/organization-bound 25-row audit history. Register entries link to receipt/history. Cheque validation/API checks and TypeScript passed. Dedicated page/form interaction verification and the current production build remain next checks, alongside certified bank evidence, bank transitions and accounting. No real custody record was created. The production objective remains active.


Cheque custody page verification — October 7, 2026: dedicated rendered-page checks passed finance authorization before reads, organization-bound parent/register/history queries, 25-row pagination and excessive-page clamping, exact JMD amounts, explicitly unchecked approval, missing/invalid/foreign-style parent handling, safe query failures and cancellation controls hidden for closed receipts. These checks render actual forms with a property-picker stub; they do not prove signed-in browser operation or form submission retry interactions. Current build session 62432 is running. Certified bank evidence, bank transitions/accounting and actual acceptance remain unfinished. The production objective remains active.

Cheque custody build checkpoint: session 62432 completed successfully, including production compilation, TypeScript and page generation with custody API/register/detail routes. Next verification remains form submission/retry interaction; next implementation remains private certified bank evidence and controlled bank/accounting transitions.


Cheque bank evidence input foundation — October 7, 2026: added separate cheque evidence normalization for deposit, clearance and return documents, with shared PDF/JPEG/PNG 8 MB/simple-filename bounds, current cheque/request references and reserve/finish/withdraw/download action validation. Actor/organization/path/hash/state are excluded from browser authority. Focused cheque validation/API/page/evidence metadata checks and TypeScript passed. This foundation does not upload or certify bank evidence; private bucket/schema/RLS, reservation/certification, immutable bank-decision snapshots, API/UI and cleanup remain unfinished. Bank actions/accounting remain unavailable pending those dependencies and approved accounting policy. The full production goal remains active.


Private cheque bank evidence schema — October 7, 2026: applied `20261007101311_private_cheque_bank_evidence.sql` with a private 8 MB PDF/JPEG/PNG bucket, fixed cheque/organization/verified-finance-uploader bindings, deposit/clearance/return evidence kinds, immutable file metadata and immutable evidence history. Authenticated finance access is limited to uploaded organization files or their own reservation metadata; direct client/service writes and Storage upload policies remain closed. Certification/state guards, reservation/upload/certification RPCs, bank-decision snapshots, API/UI/cleanup and remote boundary verification are next unfinished dependencies. No real file was uploaded. The production objective remains active.


Cheque evidence state and boundary verification — October 7, 2026: applied `20261007101351_cheque_evidence_state_guards.sql`. Certified hash/size/time cannot change, uploaded records cannot reopen, and withdrawn/expired evidence cannot revive or change certification metadata. Remote rolled-back foundation verification passed private bucket bounds, uploader-only reservation reads, other finance reads only after certification, manager/foreign isolation, direct client certification denial, missing certification rejection, immutable object path/hash/history and withdrawn-state protection. No real bytes were uploaded. Scoped reservation/trusted certification, bank decision snapshots, API/UI/cleanup and real Storage acceptance remain unfinished; the production objective remains active.


Cheque evidence upload database workflow — October 7, 2026: applied `20261007101517_cheque_evidence_upload_workflow.sql`. Verified current admin/finance users reserve bounded deposit/clearance/return files against an open organization cheque; exact retries reuse reservations and changed retries fail. Generated object paths, ten current files per cheque and fifty reservations per uploader per day are enforced under organization lock 119. Storage permits only the uploader's unexpired reserved path, with organization finance reads after certification and no client overwrite/removal. Service-only certification checks current finance identity, cheque state, reserved size/MIME/hash and object presence; exact retries do not duplicate history. Uploader-only withdrawal closes reads. Remote rolled-back checks passed reservation retry/change bounds, private reserved/certified access, client certification denial, missing-object denial, identical certification/withdrawal retries, other-uploader withdrawal denial, foreign access denial and closed-cheque reservation denial. Storage metadata was simulated in the rolled-back fixture; no real file bytes were transferred. Trusted byte-inspecting API, staff upload controls, bank snapshots/transitions, cleanup/quota/expiry/concurrency expansion and live Storage acceptance remain unfinished. The production goal remains active.


Cheque evidence server API — October 7, 2026: added `/api/staff/cheque-evidence` with verified admin/finance authorization, same-origin bounded mutations, server-credential gates, scoped reservation/signed upload URLs and uploader/organization-bound completion/withdrawal lookups. Certification downloads actual bytes, checks reserved size and basic PDF/JPEG/PNG format, computes SHA-256 on the server and supplies the verified actor to the service-only RPC. Authorized uploaded-file downloads use 120-second links and private/no-store responses. Focused cheque evidence API checks cover credential/access/body/authority boundaries and byte-derived certification; an initial copied fixture used invoice-only kind/bucket values and was corrected to the cheque contract. Staff upload controls, bank decision snapshots/transitions, cleanup/concurrency and live Storage acceptance remain unfinished. No real file was transferred. The production goal remains active.


Cheque evidence staff controls — October 7, 2026: connected receipt detail to a bounded organization/cheque-scoped current evidence list and private upload/download/certification/withdrawal controls. Current verified finance users can upload to open custody receipts; existing file completion/withdrawal controls are uploader-only. Server credentials remain server-side as a readiness boolean. Same-file reservation/transfer state persists for ambiguous upload/certification retry, with one in-flight action and basic-format-versus-bank-authenticity disclosure. TypeScript passed. The page fixture was extended for the new bounded evidence query and browser-client import; cheque regression is running. Dedicated uploader ownership/upload interaction verification, current production build, bank evidence freezing/transitions, cleanup and live acceptance remain unfinished. No real file was uploaded; the production goal remains active.


Cheque evidence interaction checks — October 7, 2026: added hook-driven upload verification for the actual cheque evidence component, including per-file uploader ownership, read-only/configuration gates, same-file request reuse, certification retry without overwrite, ambiguous transfer response recovery and oversize rejection before network calls. The focused cheque regression and production build are running as session 78206. Bank evidence freezing/transitions/accounting, cleanup/quota/expiry/concurrency expansion and real signed-in/provider acceptance remain unfinished. The production goal remains active.

### Cheque evidence build and bounded reads

The production build completed successfully, including TypeScript and all generated routes (session 78206). Cheque detail now loads certified files and unexpired reservations separately, with ten-row bounds on each query; expired reservations cannot crowd out usable evidence. Page verification includes both bounded reads and safe evidence-load errors. Frozen bank evidence, controlled bank transitions and accounting integration remain in progress; no real cheque, bank action or ledger credit was created.

### Frozen cheque bank evidence and controlled custody transitions

Applied migrations `20261007102327` and `20261007102540` to the linked Open House Supabase project. Bank decisions atomically record the current revision and retain a matching certified deposit, clearance or return document snapshot, including hash, size and reference. Used documents and snapshots are immutable. Exact retries preserve one event and snapshot; changed retries, stale revisions, wrong document kinds, premature clearance and terminal revival are rejected. Organization/finance read boundaries and frozen withdrawal/deletion were verified by rolled-back database fixtures. These are recorded custody decisions, not automated bank confirmation or ledger posting. API/UI bank controls remain to be connected and verified, followed by cleanup, concurrency coverage and approved accounting integration.

### Finance bank controls connected

Cheque API now accepts canonical deposit, clearance and return requests through the audited RPC. Finance detail shows stage-specific bank actions, matching certified evidence choices and explicit approval. Used files remain downloadable but withdrawal controls are hidden; retained decisions display revision, bank reference and exact document metadata. New form verification covers uncertain retry identity, changed payloads, evidence/approval checks and duplicate-submit locking. TypeScript passed before the new interaction tests; the expanded cheque suite and production build are running in session 84680. Accounting, evidence cleanup and concurrency verification remain outstanding.

### Cheque evidence cleanup verified

Applied migration `20261007103008`. Cleanup has service-only, bounded claims; organization locks; five-minute leases; signed-upload grace periods; system expiry audit; and frozen-document exclusion. The authenticated job removes Storage objects before calling the guarded purge RPC. Rolled-back SQL fixtures passed eligibility, grace/protected evidence, wrong/stale claims, replacement claims, marker retries, object-presence and twenty-row batch checks. All eight cheque verification scripts passed. Production build session 84680 ended with process exit 139 without a compiler diagnostic; alternate Webpack build session 62360 is running. Concurrency checks, accounting integration, production credentials and actual scheduler acceptance remain open.

Webpack production build session 62360 completed successfully (exit 0): compilation, TypeScript, route generation and build traces passed. The default Turbopack process crash remains a separate build-runtime issue to investigate; it was not a successful build.

### Full regression and cheque bank boundaries

Full regression session 59474 completed: 37/37 verification groups passed. The expanded remote rolled-back bank fixture also passed pending-upload decision rejection with unchanged revision, direct deposited-to-returned custody, use of another verified finance colleague’s evidence, unverified finance read/action denial, and unchanged journal count. These results do not prove live bank authenticity, bank transport or accounting integration. Default build is being rechecked after its prior process crash; the alternate Webpack build remains verified successful. Concurrent cheque transaction checks remain next.

### Cheque transaction concurrency verified locally

Isolated fixture `scripts/verify-cheque-concurrency.py` passed on PostgreSQL 14.19 with observed waits between independent sessions: duplicate reservation, certification then deposit, exact decision retry, stale competing decision, withdrawal against frozen evidence and exclusive cleanup claims. One audited deposit event and snapshot were retained. The fixture used simulated Storage metadata, no cloud credentials and no TCP listener; its temporary database was removed and local server stopped. This does not establish PostgreSQL 17 or live Storage acceptance. Full regression remains 37/37 passed; Webpack production build is successful. Default Turbopack recheck session 38704 remains live without new output. Approved accounting integration and resident lifecycle work remain open.

### Controlled cheque ledger engine verified

Default Turbopack production build session 38704 completed successfully (exit 0), including TypeScript and route generation; both default and Webpack builds are now verified. Applied migration `20261007103744`: verified finance can explicitly approve one exact balanced cleared-cheque journal using an approved organization asset debit and distinct approved credit account. Immutable linkage binds the current certified clearance, cheque amount, property, approval and journal. An approved bank return reverses a linked posting atomically, without duplicating an existing reversal. Rolled-back SQL checks passed stale revision, foreign/nonasset account denial, exact and changed retries, duplicate posting denial, immutable linkage, exact opposite return balances and deferred balance constraints. The first fixture used an invalid revision below the accepted range when testing staleness; corrected to a valid mismatched revision and reran successfully. Posting API/UI, ledger concurrency and signed-in acceptance remain next. Resident allocation and billing still require tenancy/business rules.

### Cheque posting API and finance screen connected

Added canonical posting validation and verified-finance, same-origin bounded API. Client amounts, journal identity, actor and organization do not enter the RPC. Finance chooses distinct approved debit/credit accounts and explicitly approves the exact cleared amount. Cheque detail reads its immutable posting and linked reversal in organization scope, shows journal links, and hides posting when already linked or unavailable. Page checks cover unposted cleared controls, returned journal/reversal links and safe error states. Existing eight cheque scripts, new posting API checks and TypeScript passed. Production build session 19687 is running; dedicated posting-form interactions, posting-versus-return concurrency and signed-in acceptance remain open.

### Cheque posting interaction and build checkpoint

Dedicated `verify-cheque-posting-form.cjs` passed: missing/same account rejection, unchecked approval, amount excluded from client authority, stable uncertain retries, changed/conflict nonce handling, success journal navigation and duplicate-submit locking. Added to the cheque group (now ten focused scripts). Production build session 19687 completed successfully with compilation, TypeScript and all generated routes. Accounting posting-versus-return concurrency, wider database boundaries and signed-in acceptance remain next; payment/billing/resident activation dependencies remain open.

### Cheque ledger races verified locally

Expanded isolated concurrency fixture passed on PostgreSQL 14.19: observed organization-lock waits for posting-first, return-first and same-request posting. Posting first produced one original journal and one exact opposite return reversal; return first rejected the later stale posting with no cheque journal; duplicate requests retained one journal/link. Earlier custody, file certification/withdrawal and cleanup races also passed. Simulated Storage metadata only; PostgreSQL 17 and signed-in live acceptance remain open. Temporary database removal was confirmed and server stopped. Supabase security advisors report no warning/error findings, with thirteen informational RLS/no-policy findings on intentionally closed private/legacy tables, including the new private cleanup claim table. See [Supabase linter guidance](https://supabase.com/docs/guides/database/database-linter?lint=0008_rls_enabled_no_policy).

### Lease preparation frozen before signing integration

Full regression session 7462 passed 37/37 groups, including the expanded cheque posting tests. Applied migration `20261007104448`: removed direct service-role draft writes and froze every prepared identity/term/snapshot field. Only an explained prepared-to-superseded/voided closure is permitted; retained drafts cannot be deleted or reopened. Expanded remote rolled-back lease fixture passed rent/participant-snapshot mutation denial, service deposit rewrite denial, deletion/unexplained closure denial, normal replacement, contact/participation guards and co-signer withdrawal invalidation. This is a prerequisite for signing; it grants no signature or tenancy authority. Signing provider selection, legal documents, billing rules and real service credentials remain pending. Provider-independent signing preparation and resident lifecycle engineering remain in scope.

### Approved legal template registry hardened

Applied migration `20261007104652`. Registered lease template versions now reject updates/deletion, validate verified organization administrator attribution and bounded metadata on insertion, and prohibit direct service-role insertion. Registration takes the organization membership lock before its template-version lock and rechecks current administrator authority. Remote rolled-back template checks passed immutable fingerprint/history, manager-attribution rejection, role/organization boundaries, exact retry and new-version retention. The full lease-draft fixture also passed after this change. Private PDF upload/certification against the approved fingerprint is not yet implemented; this was the required registry protection before that handoff. Signing provider and legal content inputs remain pending.

### Private legal PDF storage foundation

Applied migration `20261007104855`: private PDF-only 8 MB bucket, organization/template/admin-bound reservations with immutable registered fingerprint, certified-document uniqueness and retained document event history. Direct client/service writes and Storage uploads remain closed until scoped workflow functions exist. Certified metadata must exactly match declared size and approved fingerprint and cannot be withdrawn, changed or purged. Rolled-back metadata fixtures passed fingerprint mismatch, immutable identity/history, private reservation visibility, certified staff reads and foreign isolation. No actual PDF was uploaded or byte-certified by this fixture. Reservation/certification/withdrawal RPCs, server upload/download API, admin UI, cleanup and signing handoff remain next.

### Legal PDF reservation and certification workflow — 2026-10-07

Applied `20261007105315_lease_template_document_workflow.sql` to the Open House Supabase project. Verified administrators can reserve a private PDF upload against an immutable approved template, retry the same request, and withdraw an unfinished reservation. A trusted server alone can certify the declared size and approved SHA-256 fingerprint after a Storage object exists. Certified documents cannot be withdrawn; verified staff in the organization can read them. Organization locks serialize these writes with staff membership changes.

The rolled-back `scripts/sql/verify-lease-template-document-workflow.sql` fixture passed reservation retries, competing-upload rejection, client certification denial, wrong-fingerprint rejection, service certification retries without duplicate audit events, manager reads, and foreign-organization denial. This is Storage metadata verification only: actual PDF byte inspection, API/UI integration, cleanup, concurrency and live signed-session acceptance remain open. The 50 uploads per administrator per day limit is an engineering default pending business agreement. No customer PDF was uploaded or signed.

The private legal PDF API now reserves administrator-only signed uploads without overwrites, checks actual downloaded PDF format, size and SHA-256 against the approved fingerprint, calls service-only certification, and issues short-lived certified downloads to verified organization staff. `scripts/verify-lease-template-document-api.cjs` passed mocked access, origin, bounded input, missing credentials, mismatch/format denial, server-derived certification, safe errors, withdrawal and scoped download cases. TypeScript passed. Actual authenticated Storage upload acceptance, UI, cleanup and provider integration remain open.

### Administrator legal PDF interface — 2026-10-07

The existing approved-template screen now includes per-version PDF status, administrator upload, verification retry, reservation withdrawal and certified private download. Server reads restrict documents to the current organization and displayed template IDs, excluding expired reservations from the active screen so abandoned history cannot hide current certification. Certified documents expose no replacement or withdrawal action. Upload attempts retain a nonce for the same selected File and skip retransmission after successful transfer; ambiguous transfer responses attempt server certification.

`verify-lease-template-document-ui.cjs` passed render checks for certified, own/other administrator reservation, expired and unconfigured states. TypeScript passed. These render checks do not yet verify asynchronous retry/double-submit interactions, server page queries, actual signed Storage uploads, browser layout or cleanup. Those remain required, along with signing integration and approved legal sources. No real PDF was uploaded.

### Legal PDF cleanup and interrupted upload recovery — 2026-10-07

Applied `20261007105740_lease_template_document_cleanup.sql`. Service-only cleanup claims at most 20 abandoned documents, uses five-minute claim leases, skips busy organization locks and waits until reservation expiry plus two hours five minutes before removal. Certified documents are excluded. Expiry retains an immutable system audit event. The authenticated job `/api/jobs/lease-template-documents` removes through Storage before calling the claim-bound purge marker; database history remains retained.

Rolled-back `scripts/sql/verify-lease-template-document-cleanup.sql` passed grace-period/certified exclusion, active-claim exclusion, wrong/expired/replaced claim rejection, duplicate marker retry, Storage-object presence denial and expiry auditing. This fixture manipulates isolated metadata only and performs no real Storage deletion. `verify-lease-template-document-cleanup.cjs` passed credential/authentication, Storage-first ordering and safe error cases. Expanded UI interaction checks passed same-file nonce preservation after network interruption, certification retry without re-upload, ambiguous-transfer recovery, oversize denial and an in-flight duplicate submission guard. The lease suite and TypeScript passed.

Required next evidence: server page query tests, actual signed-session upload acceptance, browser layout, cleanup concurrency/batch-boundary verification and scheduled deployment credentials. Provider signing/billing choices and approved legal PDFs remain external launch inputs; no production lease has been signed or activated.

### Legal document page and full regression — 2026-10-07

`verify-lease-template-page.cjs` passed administrator gating, organization and displayed-template document filters, certified/unexpired reservation selection, bounded reads, current-version lookup independent of pagination, empty states and fail-closed count/template/document errors. The rolled-back cleanup fixture also passed a 25-document batch split into 20 and 5 without reusing current claims. Full `npm test` passed all 37 verification groups with the expanded lease checks. These are local mocked and metadata-fixture checks; signed-session Storage acceptance, real file bytes, scheduled workers, cleanup concurrency and business-provider acceptance are not proven by them.

The production Turbopack build passed after the legal document routes and page changes: compilation, TypeScript, page-data collection and static generation all completed successfully. Build verification does not establish live authentication, Storage delivery or signing-provider operation.

Supabase security advisors returned 14 informational `rls_enabled_no_policy` findings and no warning/error findings. The newly added private legal cleanup claim table deliberately has no client policy and all direct grants revoked; access runs through service-only functions. Existing closed/legacy tables remain listed. [Advisor explanation](https://supabase.com/docs/guides/database/database-linter?lint=0008_rls_enabled_no_policy). This does not replace the remaining concurrency and live-session acceptance checks.

### Lease preparation membership serialization — 2026-10-07

Applied `20261007110202_lease_preparation_membership_lock.sql`. Draft preparation previously obtained its application lock after an initial organization check without sharing the staff-membership serialization lock. It now takes the organization membership lock (119), rechecks verified preparation authority, then takes the application lock (116) and template lock (117). Membership edits and approved template registration already use 119 first. Frozen draft terms and exact retry semantics remain unchanged; revoked staff cannot retrieve a prior result through the write RPC.

The full rolled-back `scripts/sql/verify-lease-drafts.sql` fixture passed immutable terms, independent preparation, version/retry checks, template version selection, approved rent snapshots, participant invalidation and the added approved membership revocation followed by denied draft retry. This is sequential PostgreSQL 17 evidence; simultaneous revocation/preparation races, version-identical concurrency and signed-session acceptance remain open. No customer membership or draft was changed by the fixture.

### Independent-session legal PDF race verification — 2026-10-07

`scripts/verify-legal-pdf-concurrency.py` passed against an isolated Unix-socket PostgreSQL 14.19 clone, using production approved-template, verified-staff, membership, document and cleanup functions plus simulated Storage metadata. Independent sessions observed advisory waits for identical reservations, competing reservations, duplicate service certification, withdrawal before certification and administrator demotion before reservation completion. Exact retries produced one document/certification event, competing uploads were rejected, withdrawn reservations stayed uncertified, and the waiting demoted administrator produced no document. Concurrent cleanup skipped a busy organization, retained the certified PDF and produced one claim per abandoned reservation.

The clone was removed and the local server stopped after verification. This establishes local concurrency behavior for the installed functions only; it does not verify actual Storage byte transfer, PostgreSQL 17 behavior, signing, lease preparation races or scheduled production operation. Those remain explicit launch gates.

### Approved vendor invoice ledger posting — 2026-10-07

Applied `20261007110654_approved_invoice_ledger_posting.sql`. Verified finance staff can explicitly approve a gross-amount accrual against an independently approved invoice. The function uses organization membership serialization, current invoice revision, approval audit and frozen source evidence; it derives exact JMD amount/property from the invoice, requires organization asset/expense debit and liability credit accounts, creates balanced journal lines atomically, and retains an immutable unique invoice/journal link. Same payload retries return the original journal; changed nonces, reused generic journal requests and duplicate invoice postings are rejected. Client/service direct link writes are closed.

The rolled-back `scripts/sql/verify-invoice-ledger-posting.sql` fixture passed unapproved/stale/classification denial, exact/changed retry, duplicate posting denial, exact amount/property binding, immutable link, foreign read denial and deferred balance constraints. Storage evidence remains simulated metadata. The finance API and invoice detail form are connected; focused API/form checks passed permission/origin/body/approval boundaries, canonical authority-free input, uncertain retry nonce preservation, conflict/changed input nonce behavior, success navigation and duplicate-submit locking. The full invoice suite and TypeScript passed.

This implementation records the approved gross invoice accrual only. Tax splits, settlement/payment providers, credit notes and reconciliation remain required work. Posting-detail-specific rendering/query failure checks, concurrency, signed-in acceptance, broader regression and a new production build remain open. No real invoice or journal was created by the fixture.

### Invoice posting acceptance boundaries and concurrency — 2026-10-07

The detail page now rejects mismatched reviewed-evidence revisions before showing review/posting controls. Expanded `verify-invoice-pages.cjs` checks cover approved/unposted finance forms, derived amount/revision, exact parent/organization posting lookup, existing journal navigation without another form, failed posting lookup, manager read-only behavior and missing/failed/stale source snapshots.

The expanded isolated `scripts/verify-invoice-concurrency.py` passed observed independent-session waits for approval before posting, identical posting retries and competing distinct posting requests. Each approved invoice produced one retained journal link and exactly two balanced gross-amount lines. Existing reservation/quota/certification/review/frozen-withdrawal/cleanup races also passed. The fixture ran on PostgreSQL 14.19 with simulated Storage metadata; PostgreSQL 17 concurrency and real signed-in acceptance remain open. Its temporary database was confirmed absent and the local server stopped.

Full local regression passed 37/37 groups. The current production Turbopack build passed compilation, TypeScript and generation. These establish local implementation checks only. Tax splits, credit notes, payment settlement/reconciliation, real chart approval, provider operation and deployment acceptance remain required before full finance completion.

### Eligible accounting account selection — 2026-10-07

The approved-account search accepts validated, bounded classification filters and applies them in the organization-scoped database query before ordering and the 26-row pagination probe. Duplicate, empty, unknown or repeated classification parameters are rejected. All endpoint responses now carry private/no-store headers. The shared picker sends its required classifications and rejects mismatched results. Invoice posting chooses expense/asset debit and liability credit accounts; cheque posting chooses asset debit accounts. Generic journal account selection remains unrestricted within the approved organization chart.

Expanded search/picker/form tests passed server classification filtering, invalid filters, wrong-class result rejection and the exact classification props used by both posting forms, alongside stale search responses, selection/clear and uncertain posting retries. TypeScript passed. Database posting functions remain the authority for actual account eligibility; these UX filters do not replace ledger validation or business chart approval.

### Invoice accounting reversal visibility — 2026-10-07

Invoice detail now loads reversal status using both the linked original journal and organization. Finance users can navigate the original and correction journals, see the approved correction reason, and are told that retained posting history prevents a second invoice posting. Failed reversal lookups show uncertainty instead of a current-posting assertion. No posting form appears for linked invoices, including reversed invoices.

Expanded page tests passed original/reversal navigation, parent/organization-scoped reversal reads, closed posting controls and safe read-failure states. The complete rolled-back invoice-ledger fixture passed an approved reversal with exact opposite account totals, retained invoice linkage, denied new posting after reversal and unchanged exact retry result. All fixture changes were rolled back; this does not implement vendor credit notes, payments or settlement reconciliation, which remain required separate business workflows.

### Preventive maintenance database workflow — 2026-10-07

Applied `20261007111633_preventive_maintenance_plans.sql`. Verified management can create/revise explicitly approved property/unit plans with scope, priority, fixed day interval and next due date. Membership locks and current revisions protect transitions; location/creator bindings and retired plans are immutable. Due active plans issue one work order through the existing management work-intake function, retain the approved occurrence snapshot, and advance the next due date from the scheduled date. No assignment, access permission or completion is inferred. Historical occurrence/event data is immutable, property/unit moves are protected, and direct client/service writes are closed.

The rolled-back `scripts/sql/verify-preventive-maintenance.sql` fixture passed exact creation/issuance retries, one shared work order/occurrence, cadence advance, stale revision denial, future/paused/retired issuance denial, foreign/finance isolation, immutable history and protected property bindings. The 50 new plans per manager per day and 1–366 day fixed-interval limits are engineering defaults pending business agreement. No customer plan or work order was created.

API, management list/detail/editor/occurrence history, explicit skipped/backlog handling, duplicate due-date revision feedback, concurrency, notifications and live acceptance remain required before the preventive-maintenance journey is complete. Calendar-month scheduling is not implemented by the fixed-day cadence; it remains tracked if approved operational requirements call for it.

### Preventive maintenance API and initial management screens — 2026-10-07

Added bounded private `/api/staff/preventive-plans` with verified management, same-origin/JSON checks, explicit approval, canonical authority-free input and safe transient-error mapping. Strict validation covers plan/location IDs, create/current revisions, actual calendar dates, fixed-day cadence, allowed state and bounded scope/reasons. Issue actions discard client scope/cadence overrides and use the database plan.

Management has an organization/state-filtered count-first 25-row queue, property-scoped creation with paginated units, and plan detail with approved revision and due-work forms. The editor retains request identity for unchanged uncertain retries, resets it after deterministic failures and uses an in-flight guard; these editor behaviors remain unverified until interaction tests. Creation is linked from authorized property controls. Retirement is explained as permanent; due-work issuance is described as distinct from contractor assignment/entry.

`verify-preventive-plan-api.cjs` passed management/origin/body/approval gates, canonical fields, real leap dates, date/cadence/version bounds, state restrictions, ignored authority/scope overrides and safe conflict/transient failures. TypeScript passed after the screens were added. New `test:preventive-maintenance` starts with API checks only and will expand. Required next: editor/page tests, occurrence/audit history, backlog handling, linked-work navigation, concurrency, browser layout and signed-in acceptance. These initial screens do not establish a completed production preventive-maintenance journey.

### Preventive occurrence and decision history — 2026-10-07

Added management-only plan history with independently paginated occurrence and decision streams. Both counts and row reads bind organization and plan; current parent access is verified before children. Issued occurrences display scheduled due date, immutable approved scope and a link to the shared work order. Decision rows show approved before/after snapshots, reason, actor and Jamaica timestamps. Out-of-range pages canonicalize before row reads; failed counts/parent/rows fail closed.

The generated work-order detail now reads a parent/organization-bound preventive occurrence and links back to the plan and its retained history. Failed source lookup shows explicit uncertainty. Existing work-order actions remain governed by their own workflow permissions.

`verify-preventive-history.cjs` passed management/parent isolation, separate count-first 25-row pagination, preserved paging state, approved snapshots, work links, empty states and failed reads. Expanded work-order page checks passed reverse source links and their parent/organization filters, as well as unavailable-source feedback. The preventive API/history checks and TypeScript passed. Editor interaction tests, initial plan page checks, backlog handling, concurrency, notifications and real signed-in/browser acceptance remain unfinished.

### Preventive editor interactions and uncertain result recovery — 2026-10-07

Added `verify-preventive-editor.cjs` coverage for unchecked required approval, real calendar dates and integer cadence, creation-only location choices, fixed-location revisions, scope-free issuance UI, network/503 stable retry identity, changed payload and conflict identity reset, create/revise/issued-work navigation and in-flight duplicate submission denial.

The API now treats missing/invalid plan IDs, revisions and issue work-order IDs as an uncertain 503 result. The editor validates response IDs before clearing retry state or navigating. An incomplete success response therefore preserves the unchanged request identity instead of creating a new request. Tests passed incomplete-result recovery with the same nonce and closed issue-result handling. The preventive API/history/editor suite and TypeScript passed. Initial page/read states, approved backlog handling, due-date reuse feedback, notifications, concurrency, browser and live acceptance remain next; full preventive production completion remains unproven.

### Preventive initial page acceptance boundaries — 2026-10-07

Added `verify-preventive-pages.cjs` checks for organization/state filtering before queue pagination, count-first page canonicalization, explicit empty states, parent-scoped property/unit selection and pagination, trusted editor props, protected detail lookup and retained-history navigation. The tests fix time around Jamaica midnight: the same plan due date does not offer issuance before the local date and does afterward. Paused plans permit revisions only; retired plans expose neither revision nor issuance controls. Denied management and failed parent/count/row reads produce no editor.

The preventive page checks passed and are included in `test:preventive-maintenance`. This is server-rendered mocked evidence, not browser or actual signed-session acceptance. Backlog/skip policy, due-date reuse feedback, notification operation, concurrency and production acceptance remain open. Existing full-platform provider and business dependencies remain tracked; this does not close the whole preventive maintenance milestone.


## Full regression and preventive navigation checkpoint — October 7, 2026

The full local regression passed 38/38 verification groups after the preventive maintenance pages and finance account classification filters were added. `npm run build` completed successfully, including TypeScript and 68 generated pages. This is local build/regression evidence, not deployed production acceptance.

Added the preventive-plan queue to verified administrator/manager team navigation. Focused navigation checks passed inclusion for management and exclusion for finance/realtor/security/nonstaff. This small navigation change followed the build; it has separate focused verification rather than an assertion that the earlier build included it.

Preventive backlog/skip policy, due-date reuse feedback, concurrency, notifications and signed-in/browser acceptance remain open. Signing/payment providers, approved billing rules, live legal sources, server credentials and full-platform acceptance continue to gate launch. The development goal remains active and the platform is not declared finished.


## Preventive issued-date protection and backlog review — October 7, 2026

Applied exact remote migration `20261007113144_preventive_due_history_guard.sql`. Changed next-due dates must follow the latest issued occurrence for that organization/plan. The controlled API maps the dedicated database denial to an explicit recovery message; internal database text remains hidden. The rolled-back Supabase fixture passed same-date and earlier-date rejection, unchanged revision/audit counts after failed revisions, existing issuance retry, future/paused/retired gates and organization isolation. The fixture creates no retained customer data.

Plan detail now displays the number of scheduled dates through Jamaica today at the current fixed-day cadence and the next date after issuing one occurrence. When another date remains due, it prompts management to review the remaining backlog before issuing more work. Schedule revision is explicitly distinguished from completed work. Paused/retired plans expose no due-schedule issuance review. Page checks cover due today, overdue two-date schedules, one-step advancement and the still-due boundary. API/history/editor/page checks and TypeScript passed after these changes.

This implements backlog visibility and issued-date reuse protection. Explicit skipped-occurrence decisions, concurrent-session proof, notification operation and actual signed-session/browser acceptance remain unfinished. No skipping policy, automatic issuance, contractor assignment or completion was inferred.

The post-DDL Supabase security advisor returned no WARN/ERROR findings and 14 INFO `rls_enabled_no_policy` notices on existing private/closed tables. Advisor status is not an end-to-end access proof; see [the RLS notice explanation](https://supabase.com/docs/guides/database/database-linter?lint=0008_rls_enabled_no_policy). The previous full 38/38 regression/build checkpoint predates this change; focused checks and TypeScript are the current evidence for this cycle.


## Preventive concurrent issuance checkpoint — October 7, 2026

Added `scripts/verify-preventive-concurrency.py`, an isolated Unix-socket PostgreSQL fixture using the checked-in preventive/work/membership migrations over minimal local foundation tables. Each race observes the first session sleeping with its transaction open and the second session waiting on the shared advisory lock before inspecting committed outcomes. Exact creation retries create one plan; exact issuance retries return the same result with one work order/occurrence and one cadence advance. Different issuance requests against the same revision yield one success and a stale revision denial. Pause-first blocks waiting issuance; issue-first blocks a stale pause. A waiting revision expecting the newly issued revision still cannot reuse the issued due date, demonstrating the guard observes committed history.

The fixture filled the shared work-intake quota using real work-intake RPC calls, then raced two due plans at the final available slot. Exactly one issued work; the rejected plan retained its initial revision and no occurrence. A real approved membership demotion committed while an issuance request waited; fresh authority validation denied the request and created no occurrence.

All cases passed on PostgreSQL 14.19 (Homebrew). The temporary database was removed and its absence verified; the local server was stopped. No cloud/customer work records were created. This is actual independent-session evidence on a minimal local foundation, not version-identical Supabase PostgreSQL 17 or signed-in production acceptance. Explicit skipped-occurrence records, notifications, real Storage/provider acceptance and full-platform launch requirements remain open.


## Explicit preventive skipped-date engine and API — October 7, 2026

Applied `20261007113746_preventive_skip_decisions.sql`. Verified management can approve one active due date as skipped with an explicit reason/current revision. The immutable skipped-date registry retains due date, organization, audit binding and frozen approved scope. The action advances exactly one fixed-day interval and creates no work order, completion, assignment or entry authorization. It uses the shared organization membership lock and fresh authority check. Exact retries retain their original result; changed or cross-action reused request IDs are denied. The due-history guard now protects both issued and skipped dates from schedule rewind. The limit of 100 skipped-date approvals per manager over a rolling day is an engineering default pending business agreement.

The rolled-back Supabase skip fixture passed single-step overdue advancement, no generated work, exact/changed/cross-action retry behavior, retained reason/snapshot, stale/unapproved/future/paused/retired gates, skipped-date rewind denial, distinct issued/skipped dates, foreign/finance isolation, immutable records and closed direct/service mutation authority. Existing preventive issuance fixture passed again after the migration. No customer records were retained.

The management API accepts canonical skip input and calls only `skip_preventive_occurrence` with request/plan/revision/reason/approval; client-supplied scope, organization, date and cadence cannot control the operation. An unexpected work-order result is treated as uncertain rather than navigating to generated work. Focused API coverage passed canonical skip fields, malformed input and uncertain-result handling. The full preventive API/history/editor/page checks and TypeScript passed for this cycle; skip controls, paginated skipped-date display, skip/issue races, notifications and real signed-session/browser acceptance remain next. The concurrency fixture now loads the new migration and updated due-history message, but has not yet been rerun against this new scope.


## Preventive skipped-date controls and decision history — October 7, 2026

Added the explicit skipped-date editor to active due management plans. The form displays the scheduled date and one-interval advancement, requires a management reason and unchecked approval, and states that it creates no work order or completed maintenance. Scope/cadence/location inputs are absent. Uncertain and malformed work-producing responses retain retry identity and do not navigate; successful skip returns to the plan. Paused, future and retired plans expose no skip control.

The existing parent/organization-scoped, count-first paginated management decision history now identifies skipped scheduled dates from frozen before-snapshots and distinguishes them from issued work. This uses the existing decision stream; a separate paginated skipped-date registry view remains open if needed for operational reconciliation.

Focused editor checks passed skip wording, absence of scope overrides, unchecked approval, stable retry identity, unexpected work-order result denial and plan navigation. Page checks passed active-due action availability and unchanged paused/retired gates. The full preventive API/history/editor/page suite passed; expanded history rendering and TypeScript passed after the history wording change. This is mocked rendered/interactions evidence, not actual browser or signed-session acceptance. Skip-versus-issue races, notification operations and the remaining full-platform launch milestones are unfinished.


## Preventive skip/issue race and production-build checkpoint — October 7, 2026

Expanded the isolated independent-session concurrency fixture to load the skipped-date migration. Exact concurrent skip retries retain one decision/result. Different managers racing skip-first/issue-first actions against the same plan revision yield one committed decision and one stale-revision denial; no scheduled date is both issued and skipped. Competing distinct skip requests also retain one skip. A revision waiting for a skipped-date commit cannot rewind to that date, even when it supplies the new revision. Existing issuance, membership-demotion and shared work-quota races passed against the expanded migration scope.

These observed lock-wait cases passed on local PostgreSQL 14.19 over minimal foundation tables. The temporary database was removed and absence verified; the server was stopped. Supabase PostgreSQL 17 concurrency and actual signed-session acceptance remain separate open gates. No customer/cloud records were created by this fixture.

`npm run build` passed after the skipped-date API, controls and history changes, including TypeScript and 68 generated pages. The full local regression subsequently passed 38/38 verification groups. Preventive notification operation, actual browser/session acceptance and the broader production milestones remain unfinished.


## Preventive notification capture and content — October 7, 2026

Applied `20261007114428_preventive_notification_events.sql`. Committed plan creation/revision, work issuance and skipped-date decisions now capture one immutable private notice record bound to organization, plan, source audit ID/revision and scheduled date. Only issued-work notices carry a generated work-order reference; its organization/property/unit binding is checked. Capture requires the actual verified management actor and the current approved plan snapshot. Authenticated clients cannot read or directly insert notice evidence; service can read only. Existing historical decisions are not backfilled for delivery.

The expanded rolled-back skip fixture passed one notice per committed decision, exact retry deduplication, kind counts, source/date/revision bindings, notice immutability and closed client/service write authority. No customer records or emails were retained/sent. Added privacy-preserving templates for the four notice kinds, strict plan/work reference validation and management workspace links. Templates exclude address/unit/scope/reasons/access instructions and distinguish skipped/issued work from completion. The new template checks, full focused preventive suite and TypeScript passed.

This is notification capture/content foundation only. Recipient/current-event eligibility, outbox bridge, worker preparation, stale suppression, monitor views and live delivery are not yet connected. Due reminders are also not implemented by decision-event capture. Existing full-platform launch inputs and PostgreSQL 17/browser acceptance gates remain open.


## Preventive notice eligibility — October 7, 2026

Applied `20261007114632_preventive_notice_eligibility.sql`. The service-only eligibility predicate verifies immutable source-event organization/plan/revision/kind, actual currently verified management actor and a seven-day notice age bound. Plan-created/revised/skipped notices require the current plan revision; skipped notices additionally require their exact retained skip registry binding. Issued-work notices require the exact retained occurrence and matching organization/property/unit work order still reported or triaged. Later plan revisions do not erase an independently actionable open issued work order; cancelled/assigned/closed work does not qualify for the ready-for-review notice. The seven-day age bound is an engineering default pending notification-policy agreement.

The rolled-back eligibility fixture passed latest-revision/open-work eligibility, superseded plan/skip exclusion, unknown-notice denial, authenticated function-access denial, actual work-order cancellation, approval-actor email-verification removal and real administrator-approved actor demotion. It retained no customer changes and sent no email. Age-bound expiry and concurrent send/revocation races were not exercised by this fixture.

The predicate is not yet called by a preventive outbox bridge or dispatch worker. Queue deduplication, configured recipient binding, pre-send suppression, monitor integration, reminders and live delivery remain unfinished. Current remote database evidence does not replace those paths or full-platform launch acceptance.


## Preventive outbox proposal and approval-review rejection — October 7, 2026

Prepared local `20261007115500_preventive_outbox_bridge.sql` for service queueing/deduplication, current-event claim/pre-send suppression and management monitoring. Automatic approval review rejected application because it replaces shared outbox constraints/claiming/monitoring/delivery checks across workflows, creating substantial disruption risk. A subsequent migration-history read returned no matching applied migration. No indirect execution or split retry was used. The proposal remains local and pending explicit approval plus broad database verification; see `docs/PREVENTIVE-OUTBOX-REVIEW.md`.

Completed unaffected preparation code in `lib/notifications/prepare-preventive.ts`. It validates an entire at-most-20 event batch before queueing, passes only canonical rendered content/reference, handles stale null results and denies queue errors or malformed successful IDs. Focused preparation checks and TypeScript passed. The helper is not invoked by the live worker and sends no emails. Existing provider/server configuration, broad regression, recipient policy and live acceptance remain open. The development goal remains active; this rejection affects the shared outbox change, not all independent engineering work.


## Preventive skipped-date register — October 7, 2026

While the shared-outbox approval remains pending, added a management-only skipped-date register linked from the existing decision history. It verifies the actual user/management membership and parent organization before count-first 25-row pagination. Due-date ordering is deterministic within the plan's unique scheduled dates. Each row displays the retained scheduled date, approved exception, actor/Jamaica timestamp and frozen scope; it explicitly distinguishes skips from completed work. Missing, wrong-action or foreign joined decision records fail closed.

Focused page checks passed organization/parent scoping, approved reason/scope, pagination and out-of-range canonicalization, empty states, read failures, missing/foreign/action-mismatched source denial and membership denial. Existing history checks and TypeScript passed. Both the skipped-page and previously checked preparation helper are now included in the focused preventive suite. Actual Supabase embedded-relation/browser acceptance remains open; no remote schema or customer records changed in this cycle.

The proposed shared outbox migration remains unapplied after automatic approval review's rejection. User approval has not arrived; no retry or bypass was attempted. Independent engineering remains available and the full-platform goal stays active.


## Unapproved outbox proposal excluded from migration execution — October 7, 2026

Moved the unapplied, approval-rejected outbox proposal from `supabase/migrations/20261007115500_preventive_outbox_bridge.sql` to `docs/proposals/preventive_outbox_bridge.sql`. A normal Supabase migration command can no longer pick up this pending shared change. The SQL remains intact and reviewable; the review document now links the non-runnable proposal and requires approval/verification before promotion to a fresh migration. No database changes, retry or bypass occurred. This protects the production migration path while independent development continues.


## Fresh-build anonymous HTTP acceptance — October 7, 2026

The older server on port 3001 returned 404 for the preventive queue and was not treated as current-route evidence. Its process working directory matched this repository, but its loaded route state was not refreshed or inferred correct. The process was left undisturbed.

A fresh production build passed, including TypeScript and the new skipped-register route. A separate temporary production server on port 3020 passed real anonymous HTTP checks: preventive queue and skipped register returned 307 sign-in redirects; the notification worker returned 401 without credentials. Added `scripts/verify-anonymous-http.py`, restricted to local origins and no redirects/proxies, for reproducible read-only checks. The temporary server was stopped after verification. This proves anonymous gates for the checked routes, not signed-in role/organization/Storage/browser acceptance.

The expanded focused preventive suite also passed, including the skipped register and unconnected preparation helper. The shared outbox proposal remains excluded from executable migrations and unapplied pending the prior approval-review rejection. The full-platform development goal remains active.


## Map selection continuity and optional device location — October 7, 2026

Changed the shared property map so selecting a home updates marker highlighting without recreating the map or discarding the user's pan/zoom. Added an explicit Use my location action; no location request occurs on render. Device location recenters the current map only, with no stored coordinate or prospect-profile mutation. Permission denial/unavailable/invalid results retain area/list browsing. Requests use bounded timeout/coarse accuracy preference; synchronous failures are caught, immediate duplicate clicks are guarded and stale callbacks after map cleanup cannot move a replacement map.

Hook-driven map interaction checks passed instance continuity, no automatic GPS request, bounded request options, permission denial, invalid coordinates, immediate duplicate-click protection and callback cleanup. The expanded discovery suite passed existing matching/preferences checks plus map checks. TypeScript passed after the synchronous-failure handler was added. Actual browser/mobile GPS permission and tile-provider acceptance remain open. The shared-outbox proposal remains unapplied and outside runnable migrations following its automatic approval-review rejection.


## Map partial-initialization and device fallback guards — October 7, 2026

Map initialization failures now remove the partially created Leaflet instance, disconnect resize observation, clear marker/current-map references and invalidate pending device requests. Location controls stay disabled until successful map readiness and after initialization failure. ResizeObserver is optional instead of making an otherwise usable map fail when the browser lacks that API.

Focused interaction checks passed partial initialization cleanup without double removal, denied late callbacks, readiness gating, missing ResizeObserver, missing geolocation and synchronously throwing device APIs. Existing selection-continuity/location checks passed; the discovery suite and TypeScript passed for the implementation. These are hook-driven tests; actual browser/mobile/device-provider acceptance is still open. No Supabase changes or notification sends occurred. The shared outbox proposal remains unapplied following automatic approval review's cross-workflow-risk rejection.


## Map control layout and build — October 7, 2026

The map location button now has a 44-pixel minimum touch height and explicit disabled styling. Device status text uses a wrapping, readable block above the map; empty status adds no paragraph margin. The map note states that device coordinates are not saved to the account. Controls remain outside the map canvas rather than covering approximate property pins.

The expanded discovery suite passed and the production build completed successfully, including TypeScript and 68 generated pages. Browser automation initialization failed twice (kernel exited during sandbox startup); no rendered mobile/device acceptance was claimed. Browser visual acceptance remains open until the automation surface or a manual review is available. These checks do not establish GPS-provider or tile-provider acceptance.

Shared outbox approval remains pending after the automatic review rejection, and its SQL remains outside executable migrations. Independent platform implementation continues; production release and the full original scope are not complete.


## Realtor preference save/delete consistency — October 7, 2026

The live matching UI now locks answer selectors, matching submission and consent while a save/delete is in flight. A synchronous request guard prevents immediate duplicate clicks before React busy state renders. Successful responses must carry the expected saved/deleted status and a valid revision (or null for deletion) before replacing stored revision or clearing consent. Malformed or uncertain responses preserve current answers/state and direct the prospect to refresh and inspect stored preferences before another attempt; no success is inferred.

Hook-driven UI checks passed in-flight edit locks, immediate duplicate denial, malformed success rejection, valid save/delete revision and consent transitions, retained current answers after deletion and network-uncertainty recovery. TypeScript passed. The UI check is included in the expanded discovery suite. Matching eligibility, transparent reasons and choice of alternatives remain unchanged. Actual signed-account preference persistence and browser acceptance remain open; no customer preferences or emails were modified by these tests.

The shared outbox proposal remains unapplied after automatic approval review's rejection and remains outside runnable migrations. The full-platform goal is active with provider, billing, activation and launch acceptance requirements still open.


## Matching preference API private/error result contract — October 7, 2026

The preference API now applies private/no-store headers to every response path, including authentication, origin, input, conflict and transient failures. Unexpected RPC failures and thrown auth/RPC calls return safe 503 uncertainty responses. Successful RPC data must match save/delete status and revision semantics; missing/invalid results cannot be reported as success. The returned success body is limited to status/revision and excludes unexpected database fields.

Expanded API checks passed private headers, canonical success output, deletion semantics, stale conflicts, allowed validation/access errors, unknown database failures, malformed successful data and thrown provider calls without exposing private error details. The expanded discovery suite and TypeScript passed. Current implementation complements the client's uncertain-result refresh path. Actual signed-account browser/database acceptance remains open. No database schema, customer preferences or emails changed during this cycle.

The shared outbox proposal remains unapplied following automatic approval review's cross-workflow-risk rejection. The full-platform production objective remains active and unfinished.


## Matching verified-account concurrency fix — October 7, 2026

Independent-session tests reproduced a verification race in the existing preference RPC: a save waiting on account serialization could commit after email verification was removed, because authority was checked only before the wait. Added a fresh verified-account lookup with an Auth-row shared lock after acquiring the account advisory lock. The row lock retains the checked verification through commit.

Applied exact narrow migration `20261007120739_matching_verification_lock.sql` after local verification. The isolated fixture observed conflicting initial saves and save/delete orderings with one winner and one stale revision. Verification-removal-first now denies the waiting save; save-first holds the shared Auth row and makes removal wait until commit. All cases passed on PostgreSQL 14.19. The temporary database was removed and absence verified; the isolated server was stopped. Supabase PostgreSQL 17 simultaneous-session acceptance remains open. No customer records were modified by the fixture.

This approved/applied narrow preference fix does not retry or bypass the separately rejected shared notification-outbox proposal. That proposal remains outside runnable migrations and unapplied pending approval and cross-workflow verification. The full production objective remains active and unfinished.


## Deployed matching workflow rollback acceptance — October 7, 2026

Added and executed `scripts/sql/verify-matching-preferences.sql` against the Open House Supabase project. The fixture passed owner identity and server-time consent binding despite spoofed payload fields, other-account row isolation, stale save/delete conflicts, unchecked-consent denial, unverified-account denial, current-revision deletion and closed authenticated direct writes. Introspection confirmed the applied function includes its account-row shared verification lock. The transaction rolled back; a separate fixture-account query verified zero retained accounts.

The expanded discovery suite passed after this check. This is deployed PostgreSQL 17 transactional/isolation evidence, distinct from the prior actual independent-session PostgreSQL 14 races. It does not prove simultaneous Supabase PostgreSQL 17 behavior, real Auth transport or signed-in browser save/reload/delete acceptance. Those gates remain open, along with approved live realtor content and the rest of the full-platform milestones.

The shared outbox proposal remains unapplied after automatic approval review's cross-workflow-risk rejection and is excluded from runnable migrations. Independent implementation and verification continue under the unchanged active production objective.

### Direct realtor introductions — October 7, 2026

Published roster cards now offer the existing verified-account enquiry form directly. Prospects can choose a realtor without completing the matching questionnaire; direct forms carry the selected realtor ID and no prefilled matching answers. The optional matching path retains its transparent results and introduction flow. Hook-driven checks prove both roster targets are bound independently, no quiz result or preference request is required, and direct messages do not include stored preferences. All four discovery checks and TypeScript pass. Approved live roster content, signed-in browser acceptance and actual delivery remain open.

### Enquiry retry controls — October 7, 2026

Listing and realtor enquiry forms now block synchronous duplicate submissions and lock inputs during transport. Uncertain network/server/malformed-success outcomes retain the original request ID and frozen details for exact retries, with an account link for checking stored enquiries. A later rejected retry does not erase the uncertainty of the original submission. A definite initial client rejection unlocks edits and starts a fresh request reference on correction. Success requires a returned enquiry UUID, uses controlled stored-status wording, and blocks captured-handler resubmission after confirmation. Hook-driven interaction checks and TypeScript pass. New test:enquiry-form joins the full regression suite. Actual authenticated browser, database concurrency and live delivery acceptance remain open.

Enquiry checkpoint verification: the final source passes all 39 regression groups. A fresh production build after the rejected-retry correction passes compilation, TypeScript and generation of 68 static pages. These are automated engineering checks, not live authenticated/provider acceptance. No deployment was performed.

### Enquiry API confirmation — October 7, 2026

The enquiry route now returns private, no-store responses on every path, catches unavailable Auth/client/RPC services, and requires a UUID result before confirming storage. Known validation and verified-account rejection remain definite client responses; unrecognized database errors and malformed successful data return 503 uncertainty so the form retains its exact retry. Provider/database exception details are not returned. The canonical RPC still receives only request, target, contact and explicit consent fields, with authenticated ownership derived in the database. Focused API and form checks plus TypeScript pass. This does not prove deployed database concurrency, signed-session browser acceptance or provider delivery; those remain open.

### Deployed enquiry intake verification — October 7, 2026

Inspected the actual Supabase PostgreSQL 17 create_enquiry function and enquiry/event access policies. New scripts/sql/verify-enquiry-intake-current.sql passes on the deployed project in a rolled-back transaction: listing and direct realtor intake, exact retry identity, changed-target rejection, server-derived email/organization, explicit consent, cross-prospect read isolation, unverified-account rejection, unpublished new-target rejection, recovery of an existing exact retry after unpublication, one submission audit and outbox row per enquiry. The initial realtor fixture correctly failed publication-readiness constraints; its corrected approved-length/coverage fixture passed. A separate post-check confirms zero fixture Auth accounts remain; no notification worker or delivery was invoked. This is sequential transactional evidence, not simultaneous concurrency/browser evidence. Inspection identified verification lookup before the per-user advisory lock and unlocked publication lookup; next work is reproducing competing verification/publication changes in isolated concurrent sessions before choosing a narrow fix.

### Enquiry verification race reproduced — October 7, 2026

New scripts/verify-enquiry-concurrency.py reconstructs the actual enquiry DDL and stable-payload function in a disposable Unix-socket-only PostgreSQL 14.19 fixture with minimal catalog/Auth foundation. It observes the second session waiting on the per-user advisory lock. Identical concurrent requests yield one enquiry and one outbox record. A separate transaction removes email verification while holding that lock; after its commit, the waiting baseline enquiry still succeeds because its verification lookup ran before waiting. This is a reproduced defect, not a passing security acceptance. No production function was changed. The disposable database was dropped (independent count zero) and fixture server stopped. Next: narrow function fix retaining a verified Auth row after account lock acquisition, then tests for verification-removal-first and intake-first order, publication changes and shared request/rate limits. PostgreSQL 17 simultaneous proof remains open.

### Enquiry verification race fixed — October 7, 2026

Applied 20261007122240_enquiry_verification_lock to the Open House Supabase project. Only private.create_enquiry changes: after acquiring the actual caller’s existing advisory lock, it reads the verified Auth row FOR SHARE and retains it through commit. Exact retries, original limits, target selection, audit/outbox insertion and private function/search-path contract are preserved. Observed-wait isolated PostgreSQL 14.19 tests pass duplicate retry, verification-removal-first rejection and intake-first verification-update waiting. Deployed PostgreSQL 17 rolled-back intake checks pass listing/realtor ownership, consent, retry, publication and atomic audit/outbox counts; a function inspection confirms the retained verified row. Local file version matches deployed migration history. Separate cleanup checks confirm zero remote fixture accounts and no disposable database; local server stopped. Security advisor returns only the existing informational RLS-without-policy tables (closed private/service and unfinished foundation tables); no new warning/error. See https://supabase.com/docs/guides/database/database-linter?lint=0008_rls_enabled_no_policy for the informational finding. Simultaneous PostgreSQL 17, publication-change races, rate-limit races and authenticated browser/provider acceptance remain open. The unrelated shared preventive-outbox proposal remains unapplied.

### Enquiry quota/publication concurrency evidence — October 7, 2026

Extended the isolated PostgreSQL 14.19 observed-session fixture. Four initial enquiries plus two competing new requests for the fifth hourly position yield one success, one rate-limit denial and exactly five enquiries, submission audits and outbox records. Duplicate retries and both fixed verification transaction orders also pass. Separate listing and realtor unpublication transactions show intake succeeds using the previous committed publication snapshot while unpublication is still in progress; target state/title/scope is not retained by a shared row lock. This observation is distinct from stale verification acceptance: publication transition has not committed when intake reads the old state. The stronger intended transaction guarantee (hold the published target through enquiry commit; wait/recheck when unpublication precedes intake) remains unimplemented. Next: narrow FOR SHARE catalog reads with both order tests, retaining exact retry recovery after unpublication. No production function was changed this cycle. Disposable database removal independently confirmed; local fixture stopped. Supabase PostgreSQL 17 simultaneous/browser/provider acceptance remains open.

### Enquiry published target retention — October 7, 2026

Applied 20261007122617_enquiry_target_lock to Open House Supabase. Only private.create_enquiry changes: published listing and realtor lookups now retain their selected rows FOR SHARE through commit, including organization/name snapshot. Existing exact retry is checked before current publication lookup, preserving recovery after unpublication. The disposable PostgreSQL 14.19 fixture observes transaction waits in both unpublication-first and intake-first order for both target types; first-order new intake is rejected with zero enquiry/outbox, while intake-first creates exactly one and safely recovers it after unpublication. Duplicate retry, verification removal/retention and competing final hourly quota remain passing. Deployed PostgreSQL 17 sequential rollback checks pass; migration file matches deployed history. Fixture accounts and disposable database independently confirmed absent; local server stopped. Version-identical simultaneous testing, signed-in browser and provider delivery remain open. No unrelated outbox function was rewritten.

### Prospect enquiry history — October 7, 2026

Added /account/enquiries, a verified-account, owner-scoped count-first history with stable created_at/id ordering and 25-row pages. Unlike the account overview’s latest 50 submissions, it provides navigation through the full stored enquiry history. Cards show property/realtor type, Jamaica submission time, exact submitted message/reference and explicit follow-up status; unknown status is not mislabeled closed. Page explains uncertain-submission recovery and that storage does not confirm a viewing. Enquiry confirmation and uncertain-recovery links now target this history; the account overview links it too. Component checks pass verified gate, actual owner predicates on both reads, stable bounds, count errors, row errors, empty state and out-of-range redirects; account and enquiry groups plus TypeScript pass. No new database permission or data mutation. Authenticated browser acceptance remains open.

The enquiry-history checkpoint production build passes compilation, TypeScript and all 68 static pages; /account/enquiries is included as a dynamic protected route. This build also includes the latest enquiry API confirmation handling. No deployment performed.

### Viewing submission controls — October 7, 2026

Viewing request UI now guards synchronous duplicate clicks, locks editable fields while transport runs, requires a returned UUID before showing success and blocks stale handler reuse after confirmed submission. Hook tests cover immediate duplicate transport, field lock, malformed-success rejection and final guard; existing viewing API checks and TypeScript pass. Full uncertain-retry snapshot handling, API unavailable-service confirmation and signed-in acceptance remain unfinished; this checkpoint does not establish complete viewing recovery. Next implement exact frozen retry details and distinguish definite rejection from uncertain storage across API/form.

### Viewing interrupted-submission recovery — October 7, 2026

ViewingRequest now freezes request ID, original slot and contact/consent fields across uncertain network/server/malformed confirmations; inputs remain locked while an exact retry or account check is available. A rejected retry after uncertainty preserves the earlier unconfirmed request. Definite initial client rejection unlocks corrections with a new request. Confirmed UI wording derives from the stored status allowlist, not arbitrary response text. API catches unavailable account/RPC/read services, masks internal errors, uses private no-store responses, validates returned UUID and requires an owner-scoped readable stored status rather than defaulting a failed/missing read to requested. Known capacity/validation/authorization conflicts and committed-expiry transition responses retain their meanings. Focused UI/API tests pass original request preservation, duplicate guards, malformed success, missing/invalid/read-error records and unknown/thrown RPC errors; TypeScript passes. Full signed-session viewing acceptance, current production build, expired request recovery and broader concurrent scheduling remain open.

### Expanded viewing recovery verification — October 7, 2026

Interaction checks now explicitly prove an authentication rejection after uncertain storage retains the original request and keeps fields locked; a definite initial validation rejection clears the attempt/unlocks fields and generates a new reference on correction; network interruption preserves uncertainty. The previous duplicate, frozen-detail, malformed response, controlled wording and completed-handler guards remain covered. Focused viewing API/UI checks pass. Anonymous HTTP verifier now includes the protected enquiry history and POST enquiry/viewing private-cache authentication gates, for execution against a separately started fresh local server. Full regression/build/runtime results are recorded separately after completion.

Viewing recovery acceptance checkpoint: all 39 regression groups pass and the fresh production build exits successfully. A separate localhost:3020 production server confirms anonymous enquiry-history and preventive-management redirects, worker authentication, and POST enquiry/viewing 401 with private no-store caching. This is actual HTTP runtime evidence for anonymous gates, not signed-in acceptance. Temporary server stopped; existing user server preserved. No records/emails/deployment created.

### Viewing action confirmation controls — October 7, 2026

ViewingList now prevents synchronous duplicate actions across all rows, locks cancellation reason/dismissal controls during transport and validates that a successful returned status matches the requested action. Malformed responses and network/server uncertainty preserve the displayed record and cancellation reason with refresh-before-retry guidance. Confirmed cancellation displays its shared reason immediately. A committed expired response is displayed truthfully as expiry without pretending cancellation/confirmation succeeded. New interaction tests cover duplicate guard, locked controls, malformed status denial, retained reason, confirmed cancellation and expiry; viewing API/request/list groups plus TypeScript pass. Actual signed-in acceptance and refreshed production build remain open for this change.

### Demand workload reporting foundation — October 7, 2026

Added /staff/reports/demand for verified admin/realtor/manager organization members and linked it from role-scoped team navigation. It uses nine concurrent exact head-only count reads, with actual membership organization predicates for three enquiry and six viewing states. No names/messages/contact data are fetched. The report explicitly labels all-date current stored-state counts, independent read timing, unresolved expired holds and absence of conversion/sales meaning. Partial failed counts display Unavailable with decision guidance rather than zero. Queue links permit follow-up. Render checks pass role denial without database reads, organization scoping, all nine concurrent states, actual count rendering and partial failure; TypeScript and staff navigation pass. Full demand/time-series/maintenance/contractor decision reports, signed-in organization acceptance and current build remain open. New test:demand-report joins the suite (now 40 groups, not yet all rerun).

### Demand submission-period filtering — October 7, 2026

Demand workload now accepts explicit start/through calendar dates through a GET form. lib/reports/period.ts validates both dates, actual calendar validity and chronological order; Jamaica midnight is fixed UTC-05 and inclusive end becomes an exclusive following midnight. Each of the nine owner-organization/status head-only counts receives the same created_at range. Invalid filters show an error and perform no report count queries, avoiding silent all-date fallback. The report explicitly distinguishes current states of the submitted cohort from events/outcomes occurring in the period; all-date reset is available. Rendered tests verify organization predicates, concurrent count queries, exact Jamaica boundaries, period wording and invalid-calendar no-count behavior; TypeScript passes. Period-to-period comparisons, true outcome/event measures, actual dataset/browser acceptance and current build remain open.

### Recorded viewing outcome activity — October 7, 2026

Demand report separates current submission cohort states from viewing audit events recorded within the event period. Four exact head-only viewing_events counts use the required inner viewing relation and actual membership organization filter, event_name confirm/complete/cancel/no_show and event-created Jamaica bounds. All thirteen workload/event counts start concurrently. UI explicitly labels repeated event counts rather than unique prospects, attendance or sales and exposes independent activity-count failures. Rendered tests pass role/scope gates, all four event kinds, exact time bounds, concurrent reads and independent failures; TypeScript passes. Actual PostgREST embedded relation/count acceptance, outcome policy review, deployment/build and authenticated browser remain open. No new data or permissions were created.

### Demand report live contract/build evidence — October 7, 2026

Actual Supabase metadata confirms viewing_events_viewing_id_fkey to public.viewings, UUID IDs, text event_name and timestamp-with-time-zone created_at. Authenticated SELECT exists; anonymous SELECT is absent. Inspected actual event policy derives access through readable parent viewings, whose staff policy checks actual membership organization/admin/realtor/manager roles. scripts/verify-demand-rest-contract.cjs uses only the configured public key, zero-result UUID scope and limit=0; live REST recognizes the embedded relation/filter query and returns 401/42501 anonymous denial rather than relationship/schema error. Default sandbox network was unavailable; approved read-only probe succeeded. This is not authenticated count or foreign-organization acceptance, which remains open. Current production build exits successfully including demand report and latest viewing action changes. No real records or credentials were printed and no data mutated.

### Authenticated demand database counts — October 7, 2026

New scripts/sql/verify-demand-report.sql passes on deployed Supabase PostgreSQL 17 in a rolled-back transaction. Actual verified realtor creates availability; prospect submits a viewing and enquiry; staff confirms and cancels, repeating each transition. Under authenticated realtor and manager roles, owner-organization cohort and parent-joined audit counts match one enquiry, one cancelled viewing, one confirmation and one cancellation event. Current Jamaica-day filters include the recorded events and following-day filters exclude them. A verified foreign-organization realtor cannot read the fixture enquiry or joined event records. Repeated transitions do not inflate event counts. The separate cleanup query confirms zero fixture Auth accounts remain; no worker/delivery invoked. This proves database query/RLS behavior for exercised roles and states, not authenticated PostgREST embedded count headers, browser rendering, all roles/states or exact-midnight fixture boundaries. Those acceptance checks remain open. No schema/function changes were made this cycle.

### Maintenance workload reporting — October 7, 2026

Added /staff/reports/maintenance and admin/manager-only team navigation. Thirteen concurrent exact head-only work_orders counts apply actual membership organization, current stored state or recorded open priority and optional validated Jamaica created-at cohort dates. Open priority includes reported/triaged/assigned/scheduled/on_site/in_progress and excludes completed/closed/cancelled. State links open existing queues, with explicit notice that queue links cover all dates. Unknown failed counts render Unavailable rather than zero. Report distinguishes current cohort state from period outcomes, and recorded urgency from contractual deadlines. Focused rendered checks pass management gate, no reads for denied access, owner-org filters, thirteen parallel counts, open state exclusion, date bounds/invalid-date no queries, partial failures and truthful copy. TypeScript and staff navigation pass. New test:maintenance-report joins the suite (41 groups; not all rerun this cycle). Actual management-role dataset/RLS count acceptance, current build, contractor reporting, time/outcome metrics and signed-in browser remain unfinished.

### Deployed maintenance report permissions/counts — October 7, 2026

New scripts/sql/verify-maintenance-report.sql passes on deployed Supabase PostgreSQL 17 in a rolled-back transaction. Actual management RPC creates urgent/high work and cancels a second urgent item. Authenticated manager counts match two reported work orders, one cancelled order, one open urgent and one open high; cancelled urgent work is excluded from the exact six-state open predicate. Current Jamaica-day cohort queries include records and following-day queries exclude them. Same-org realtor, foreign administrator, unverified manager and prospect roles cannot read fixture work records. Independent cleanup confirms zero retained fixture Auth accounts. No worker/emails or schema changes were invoked. Coverage is sequential database/RLS evidence for exercised states/roles, not authenticated REST/browser, exact-midnight boundaries or all nine lifecycle states; those remain open. Current maintenance-report production build remains unverified.

### Contractor coordination reporting — October 7, 2026

Added /staff/reports/contractors and admin/manager-only navigation. Nine concurrent exact head-only counts cover all five contractor offer and four visit states, restricted by actual membership organization and optional validated Jamaica creation-date cohort. Report labels record creation rather than appointment/response dates, historical accepted offers, unresolved elapsed offered windows and absence of entry/attendance/completion authority. Record counts do not claim unique contractors or performance ratings. Work-order/register links support drilldown; failed counts show Unavailable. Rendered checks pass management denial without reads, scope, all nine counts, date bounds/invalid period, independent failures and truthful semantics; TypeScript/navigation pass. New test:contractor-report makes 42 groups (full suite not rerun this cycle). Actual manager/foreign/contractor database count acceptance, current build, browser walkthrough, per-contractor/outcome reports and full reporting milestone remain open.

### Reporting regression/runtime checkpoint — October 7, 2026

All 42 verification groups pass with current demand/maintenance/contractor reports and viewing changes. Current production build exits successfully after compilation, TypeScript and generation. Reviewed report server authentication, request-local state, concurrent independent reads, minimal head-only counts, semantic tables/labels, and invalid-period failure behavior using the React best-practices checklist. Fresh localhost:3020 production HTTP checks confirm anonymous redirects for all three report pages and protected account/preventive routes plus worker and private-cache submission authentication gates. Temporary server stopped, existing user server preserved. No deployment or actual email. The plan’s current queue now identifies reporting and retained provider/approval gaps. Authenticated REST/browser acceptance, contractor reporting dataset proof, all remaining original milestones and external launch inputs remain open.

### Contractor database reporting acceptance — October 7, 2026

scripts/sql/verify-contractor-report.sql passes on deployed Supabase PostgreSQL 17 in a rolled-back transaction. Actual verified management approves a contractor, creates/triages work, offers approved scope and proposes an appointment. The authenticated contractor accepts and confirms with an exact confirmation retry. Management counts match offered/proposed and accepted/confirmed stages; current Jamaica-day created-record cohorts include them and following-day creation cohorts exclude the future appointment. Unverified management, foreign management, same-organization realtor and prospect cannot read the organization’s coordination records. Independent cleanup confirms zero fixture Auth accounts. No delivery invoked. This proves exercised database/RLS behavior, not authenticated REST count headers, browser rendering, every state/admin role or exact-midnight boundaries.

### Independent report transport recovery — October 7, 2026

All three reports now share reportCount: rejected query promises/thenables and database error responses produce an independent Unavailable count; negative, fractional, non-finite, unsafe or non-number counts are rejected. Valid zero remains zero. No raw transport/database detail reaches the report. Existing report scope/concurrency/date/render checks, new count rejection/value checks and TypeScript pass. Full regression rerun follows; the last production build predates this helper change. Signed-in REST/browser and remaining release gates remain open.

Recovery regression/build checkpoint: all 42 verification groups pass after reportCount integration. Initial fresh build compiled and passed TypeScript but its Node 22.19 V8 worker trapped during static generation (Unknown type: 7000); unchanged rerun exits successfully, generating all 68 static pages and all report routes. Record the transient native failure for recurrence rather than claiming the first attempt succeeded. No code changes were required for retry; no deployment performed.

### Explicit applicant lease-summary handoff — October 7, 2026

Applied 20261007130036_shared_lease_summary_release. Independent verified organization staff can explicitly release the current approved prepared draft’s basic terms for its applicant, with a held reservation, current draft/application versions, verified matching applicant contact and sharing attestation. Organization authority/application locks and verified Auth row retention protect material release checks. Immutable release records preserve actor/request/reference, exact retries and one release per draft; direct client/service writes are denied. Applicant-only RPC projects bounded 25-row released history using actual verified ownership, exact money strings and current draft state; internal references/reasons, full snapshots, legal source paths and other participants’ contacts remain excluded. Unreleased replacement versions remain hidden. Release does not produce a signature, payment, tenant identity/access or notification.

Staff draft history now has current-version release controls and scoped release-state reads; read failures disable sharing. New /applications/[id]/lease and owner application link show shared terms, historical replacement/withdrawal warnings, exact JMD, pagination, missing versus failed history, legal/signing/payment/move-in distinctions. In-flight duplicate/completion guards and frozen uncertain retries preserve the original approval/request; returned UUID/draft/version/state must match. The API enforces origin/body/verified staff access, excludes client authority fields and returns private no-store safe errors.

Deployed PostgreSQL 17 rolled-back fixture exercises real application/document review/co-signer/approval/reservation/template/preparation transitions; unreleased exclusion, independent release, exact retry, changed/duplicate/stale/unapproved denial, applicant-only redacted terms, second-page bounds, foreign/co-signer/unverified denial, immutable audit, unreleased replacement exclusion and released superseded/voided history pass. Independent cleanup confirms zero fixture Auth accounts. No provider or delivery invoked. Security advisor reports only 15 existing informational RLS-without-policy records for intentionally closed internal/legacy tables; none names the new release table/functions. Focused API/input/page/staff/UI checks and prior lease group pass; all 43 regression groups pass. Current production build/runtime checks follow. Actual authenticated REST/browser, production concurrency, applicant review/acknowledgment, co-signer legal handoff, full PDF generation and approved signing/payment/resident activation remain open.

Lease summary release acceptance checkpoint: expanded deployed fixtures also deny changed applicant contact, unverified applicant release, unverified owner summary reads and exact release retry after staff revocation. They pass with independent zero-account cleanup. Current production build exits successfully (69 static pages; applicant lease route and staff release API included). Fresh separate localhost:3020 HTTP checks confirm sign-in redirects for applicant/staff lease pages, prior report/account/preventive gates and 401 private no-store response for the new release API. Temporary server stopped; existing user server preserved. React checklist reviewed request-local state, minimal applicant projection, bounded dependent staff release reads, semantic labels/history/navigation and immediate/frozen action guards. No commit, deployment, signing, payment or delivery. Signed-in browser/provider/concurrency acceptance and full original lifecycle/native/release scope remain open.

### Shared lease summary review and questions — October 7, 2026

Applied 20261007131430_lease_summary_review after correcting a SQL quote; the failed initial attempt rolled back with no table/history entry. Verified actual applicants can record a review or ask a question on a released, current prepared draft; independent verified organization staff can reply to the latest unanswered question. Pending questions cannot silently be marked reviewed. Staff cannot impersonate applicant review and applicants cannot impersonate staff answers. Actual authority is rechecked after actor/organization/application locks, with verified Auth row retention; current approval/reservation/draft and applicant contact are checked. Review revision conflicts prevent overwriting intervening responses; exact actor/request/payload retries preserve the same immutable event, including later historical retries. Actor locks serialize the 50-response/day quota across organizations. Review actions never sign/accept a lease, collect payment or activate resident access.

New append-only shared history has participant RLS and column grants excluding private actor UUID/request IDs; anonymous/direct service writes are denied. Applicant/staff history RPC projects only shared events and basic summary terms, with current state and 25-row descending revision pages. Shared review page /applications/[id]/lease/[draftId] is linked from both lease histories, binds the route draft to its returned summary and derives role/current/revision from the database. Forms gate current version, unanswered question and role; explicit review-only acknowledgment, synchronous duplicate/completion guards, locked controls and frozen uncertain retries protect submissions. Safe API validates origin, verified sign-in, bounded body/message/acknowledgment and exact returned UUID/release/revision/action; all responses are private no-store. Failed history/permissions never become an empty conversation or enabled form.

Deployed PostgreSQL 17 rolled-back fixtures pass actual review→question→reply, exact retries, changed/stale/unacknowledged/role-mismatched denial, pending-question preservation, immutable history, redacted actor fields, foreign/co-signer/unverified isolation, 27 real responses split into correctly ordered 25/2 pages, replaced-summary current=false/new-response rejection and historical retry. Independent cleanup confirms zero fixture Auth accounts. No emails/provider operations. Security advisor returns the same 15 existing informational no-policy findings for closed internal/legacy tables; none names the new review table/functions. Focused API/history/page/form checks, previous lease groups and all 44 regression groups pass. Current production build exits successfully (70 static pages). Fresh separate localhost:3020 HTTP checks confirm review-page sign-in redirect and POST review 401 private no-store alongside prior gates. Temporary server stopped; existing user server preserved. React request-local/minimal serialization/semantic labels/conditional forms/frozen refs checklist reviewed.

Remaining acceptance includes actual signed-session REST/browser, quota boundary and production-version concurrency/revocation races, management unanswered-question queue, notification delivery, approved legal PDF/co-signer signing handoff, signing/payment providers and resident activation. This review is a shared discussion feature, not completion of the lease/resident/native/release milestones.

### Staff unanswered lease question queue — October 7, 2026

Applied 20261007132447_lease_review_queue: public.pending_lease_review_questions is a security-invoker view retaining actual draft/release independent staff RLS and shared-event participant RLS. It selects only the latest question per released version, requiring current prepared draft, matching current application approval/version and held organization reservation. A reply removes the pending row; draft replacement also excludes it. No new write/signature/payment/notification authority is added.

New /staff/lease-reviews is linked from role-scoped team navigation and the staff application inbox. Verified admin/realtor/manager access, actual organization predicates on both count and row reads, count-first 25-row pages and oldest asked-at/release-id ordering connect directly to shared discussion/reply. Count/row failures display an alert; a positive count with no rows displays changed-queue guidance rather than a false clear queue. Conditional Supabase column-list inference initially failed TypeScript; the explicit static projection fixes it, and count reads remain head-only. Focused role/scope/pagination/order/empty/error/race checks, navigation and TypeScript pass; all 45 regression groups pass. Current build/runtime verification follows.

Deployed PostgreSQL 17 rolled-back fixtures prove management sees a current pending question, replies remove it, a later new question reappears, applicants cannot read the management queue, foreign/co-signer/unverified callers see none, and replacement removes the pending row. Independent cleanup confirms zero fixture Auth accounts. Security advisor reports the same 15 existing informational no-policy findings for closed internal/legacy tables and no new view finding. Actual signed-session REST/browser queue walkthrough, concurrent queue/reply/revocation acceptance, reminders/delivery and all remaining legal/provider/resident/native/release milestones remain open.

Lease question queue verification checkpoint: all 45 regression groups, TypeScript and the current production build pass. Fresh separate localhost:3020 production HTTP checks confirm the new queue’s 307 sign-in redirect and all prior lease/report/account/worker/private-cache API gates. Temporary server stopped. Reviewed request-local state, actual organization filters, head-only count, bounded dependent row reads and semantic error/empty/changed states. Signed-in queue/reply walkthrough, production-version concurrency, live delivery and remaining original milestones stay open; no release/deployment occurred.

### Equal-length demand comparison — October 7, 2026

Added /staff/reports/demand/compare, linked from demand workload with selected dates preserved. Explicit valid Jamaica date ranges compare with the immediately preceding nonoverlapping range of equal length. All 26 organization-scoped head-only exact counts start concurrently; unavailable counts suppress their deltas, and signed differences use exact integer arithmetic without percentages or zero-baseline inventions. Current submission-cohort states and recorded event-period counts remain explicitly distinguished. Invalid or missing dates issue no queries. Focused rendered checks cover organization gates, query concurrency, rejection recovery, date bounds, leap/year boundaries and semantics; TypeScript passes. Full regression and production build are running. Existing deployed demand permissions/fixtures remain applicable; authenticated comparison REST/browser and concurrent dataset acceptance remain open. No database mutation, notification, signing, payment or deployment is added.

Demand comparison verification checkpoint: all 45 regression groups and current production build pass. Fresh separate localhost:3020 production HTTP checks confirm comparison 307 sign-in redirect and existing lease/report/account/worker/private-cache API gates. Temporary server stopped. Actual authenticated comparative datasets/REST/browser acceptance remain open, alongside original legal/provider/resident/native/release milestones. No production deployment occurred.

Demand comparison database checkpoint: deployed PostgreSQL 17 authenticated realtor/manager cohort and joined-event comparisons pass using actual enquiry/viewing/confirmation/cancellation workflows and synthetic rolled-back boundary timestamps. Previous-period enquiry and confirmation, selected-period cancelled viewing/cancellation, inclusive starts/exclusive ends and foreign organization denial are verified. The first fixture correctly failed the enquiry audit guard because the prior foreign identity remained selected; selecting the actual fixture staff identity resolved it without permission changes. Independent cleanup confirms zero fixture Auth users. This is sequential SQL acceptance, not authenticated REST/browser or production concurrency acceptance. Next independent workstream: native Expo identity and shared-record discovery foundation; provider-backed tenancy activation remains gated on approved inputs.

Native identity foundation checkpoint: created isolated mobile/ from the official Expo 57.0.29 TypeScript template with generator 5.0.0, resolved/pinned Expo 57.0.27, React 19.2.3 and React Native 0.86.3 dependencies and a separate lockfile. Root Next TypeScript excludes the native workspace. Expo Router entry/verified-account sign-in uses the supplied blue logo, native encrypted SecureStore without plaintext fallback, foreground refresh, fresh getUser verification, no user-selected role authority, response epochs and listener cleanup. Focused identity/storage checks pass and are added as test:native-identity. Native lint and TypeScript pass; separate iOS and Android Hermes bundle exports pass. Optional peer conflicts were resolved with SDK-compatible React DOM/reanimated/worklets. Expo lint config React plugin fails on ESLint 10; compatible 9.39.5 passes but npm labels it unsupported, so tooling upgrade remains a release item. Local ignored native configuration contains only the already configured public Supabase URL/key, no server secrets. Launcher/splash assets, actual device/auth persistence, public inventory/maps, all five native role journeys, camera/deep links/push and native build/store release remain unfinished. No EAS project, identifiers or deployment were provisioned. Continue native discovery and shared-record journeys while external signing/payment inputs remain pending.

Native property discovery increment: /listings and /listings/[id] now read only the explicit public listing projection with status=published. Search/area/buy/rent filters reuse the web sanitizer, exact validated head-only counts precede stable published_at/id pagination bounded to 24, and vanished results remain a changed-inventory state rather than false zero. Malformed records/coordinates fail safely, money formatting uses exact decimal components, remote images are HTTPS-only and private/internal fields are excluded. List/map views share the current result page; only approved approximate points render, selecting a marker opens the associated card/detail, device location is disabled and no exact-address/directions authority is claimed. Details support approximate-area external handoff with failure feedback. Native map library is SDK-compatible/pinned; Android Google Maps key is a build environment input through app.config.ts, iOS uses native Apple Maps, and web preview falls back to area links. Focused catalog/map/query-lifecycle tests pass, including failed/malformed counts, filters, pagination, stale response/unmount suppression and immediate refresh hiding. Live read-only REST acceptance passes all/rent/sale and missing detail without printing keys/content or writing records. Native lint/TypeScript and both iOS/Android Hermes exports pass. First export failed on the outside-mobile shared helper; extending Expo default Metro watch folders only to the shared pure discovery directory resolved it. Full regression and web-preview export checks are running. Actual devices, approved Android map key/identifier/certificate, native save/enquiry/viewing/application journeys, all private role flows, camera/push/deep links and original provider/resident/release milestones remain unfinished.

Native discovery verification checkpoint: all 47 regression groups pass, including native identity/catalog/lifecycle checks; root and native TypeScript and native lint pass. Final web preview and iOS/Android Hermes bundle exports pass after making browser sessions explicitly in-memory (native sessions retain SecureStore; no plaintext persistence fallback). Extreme valid coordinate spreads are clamped to supported map region deltas and covered by focused checks; corresponding final native bundles are being refreshed. Public live REST checks are read-only. Device tile rendering, selection/keyboard/accessibility interaction, authenticated private journeys and all original provider/resident/native release gates remain open. No deployment, EAS project or maps account provisioning occurred.

Final native discovery checkpoint: refreshed iOS/Android exports after map-region bounds checks both exit successfully. No live processes remain from verification. Next dependency-ready work: native verified saved properties, enquiry/viewing and account/application journeys on shared authorized records; realtor preference matching and management/contractor/security experiences follow. The original full production objective remains active.

Native saved-property increment: property details now offer verified-owner save/remove controls and /saved provides count-first 24-row shortlist pagination, published-only bounded detail projection and redacted unavailable placeholders. UID comes from the verified identity provider, with fresh getUser checks before and after every private read and after desired-state writes. Ownership predicates are explicit; foreign/malformed results, failed/invalid counts and identity changes fail safely. Save/remove uses explicit desired state, duplicate-submit ref locks, same-desired-state uncertain retries and separate current-status recovery; success is shown only after owner-scoped readback. Identity-keyed controls/pages and mounted response guards suppress previous-account/background/unmount feedback. Applied 20261007140749_verified_saved_property_access adds a private actual Auth verified-UID helper to the existing saved-listing select/insert/delete policies; no wider authority or update grant added. Deployed PostgreSQL 17 rolled-back fixtures pass owner writes/reads/removal, duplicate saves, foreign/unverified/revoked denial, paused listing redaction and retained removal. Initial fixture transport returned expired request state; independent inspection showed zero fixture accounts/running queries before successful retry. Independent final cleanup confirms zero accounts. Advisor reports the same 15 existing informational no-policy findings on closed internal/legacy tables, no new saved access finding (reference: https://supabase.com/docs/guides/database/database-linter?lint=0008_rls_enabled_no_policy). Focused data/control checks, native lint and TypeScript pass; full regression and all-platform exports are running. Actual signed-session REST/device/private-journey and version-identical revocation concurrency acceptance remain open; no client distribution or production release occurred.

Native saved-property verification checkpoint: all 48 regression groups, root/native TypeScript and native lint pass. Updated iOS/Android Hermes and web preview bundle exports all exit successfully. Deployed rolled-back saved access fixtures and independent cleanup pass; no fixture/customer records, emails or deployment were created. Next dependency-ready work: native enquiry/viewing intake and owned account/application journeys, followed by realtor matching and remaining role experiences. Actual authenticated REST/device sessions, production-version revocation races and all original legal/provider/resident/native release gates stay open.

### Native enquiry transport checkpoint — October 7, 2026
The native enquiry helper now validates bounded contact details and explicit consent, freezes a request reference and payload for exact retries, verifies the current owner before submission and after confirmation, and calls the existing audited `submit_enquiry` RPC. Known database rejections are distinguished from uncertain transport, malformed confirmation and identity-change responses. Focused helper verification passes. This is transport preparation: the native form, owned enquiry history, viewing journey and device acceptance remain unfinished; it does not establish production readiness or email delivery.

### Native property enquiry UI — October 7, 2026
The property detail enquiry form is implemented with verified identity, consent, secure UUIDs, frozen uncertain retries, duplicate-tap locks, confirmation and unmount suppression. Helper and component checks pass; native TypeScript and lint pass. Device/session acceptance, owned native enquiry history and viewing screens remain unfinished. Expo Crypto is pinned to SDK-compatible 57.0.3 in the manifest and lockfile.
Verification for this increment: all 49 automatic test groups passed, native TypeScript and lint passed, and Expo exports completed for web, Android and iOS. These are JavaScript/Hermes bundles, not signed app builds or device acceptance. No schema change, deployment or actual enquiry/email was performed in this increment.

### Native enquiry history — October 7, 2026
Implemented owned, paginated enquiry history with fresh verified identity before/after reads, explicit ownership predicates, minimal projection, stable ordering and strict response validation. Added account-home and submission-recovery navigation. Focused native enquiry tests, native TypeScript and lint pass. No actual customer enquiry, schema mutation or deployment was performed. Signed-device/private-session acceptance and viewing journeys remain open.

### Native viewing transport and availability — October 7, 2026
Implemented strict, immutable viewing request inputs, fresh verified owner checks, the existing audited request RPC and explicit owned status readback. Network/malformed/readback/identity-change failures remain uncertain; known initial database rejections remain correctable. Published availability reads are property-bound, limited to 20 future open or expired-held slots and validate identities, durations, times and states. Focused tests, native TypeScript and lint pass. This is native transport preparation: time selection/contact UI, owned viewing history/cancellation and device acceptance remain unfinished. No real appointments, schema changes or deployment were performed.

### Native viewing request form — October 7, 2026
Implemented time selection and contact-consent intake on published property detail. Times display explicitly in Jamaica; available/error/empty states have refresh. Frozen uncertain retries and duplicate/completion/unmount guards pass focused component checks alongside helper checks. Native lint and TypeScript pass. This reuses the actual request RPC and owned stored-status confirmation. No actual appointment, email, deployment or schema mutation occurred. Native appointment history/cancellation and signed-device acceptance remain unfinished.

### Native appointment history — October 7, 2026
Implemented owned, count-first 25-row appointment history with minimal projection, stable ordering, verified identity before/after reads and strict response checks. Home and viewing submission recovery link to the screen. Stored status, Jamaica time, confirmation window, cancellation reason and public-property links are displayed; elapsed windows do not fabricate a database transition. Focused viewing helper/form/history checks and native TypeScript pass. Cancellation controls and signed-device acceptance remain unfinished. No real appointments, deployment or schema changes occurred.

### Native owner cancellation — October 7, 2026
Appointment history now offers cancellation for future requested/confirmed appointments with a required 5–500 character reason. The helper verifies the owner, invokes the existing audited cancellation transition and checks exact owned stored status before reporting a result. The UI freezes the reason for uncertain retries, suppresses duplicate/completed actions and ignores unmounted responses. Focused transport checks include malformed/failed/readback mismatch outcomes and ownership predicates. Native cancellation component/device interaction acceptance remains open; no actual customer appointment or deployment occurred.

### Native cancellation interaction verification — October 7, 2026
A focused component runner now verifies reason gating, synchronous duplicate locks, disabled busy fields, frozen uncertain reasons, preserved retry state after later known rejections, confirmed cancellation text, explicit refresh and late-response/action suppression after unmount. These checks pass alongside viewing transport, intake and history checks. Real-device interaction, signed-session database acceptance and live delivery remain open; component fixtures do not prove them.
Broad verification for the native viewing checkpoint: all 50 automatic verification groups passed and Expo exports completed for web, Android and iOS. Native lint/TypeScript passed after the prior appointment-clock correction. Exports are bundles rather than signed app/device acceptance. No production readiness claim follows from these checks.

### Native realtor directory — October 7, 2026
Implemented public realtor roster loading/validation and a native directory linked from home, with loading/error/empty/refresh states. Only published public fields are queried; unsafe photo URLs are omitted and roster overflow cannot silently produce incomplete matching results. Focused checks verify strict profiles, redaction, publication scope and shared ranking. Matching questionnaire, introduction requests and saved preference controls remain unfinished. No business profiles, schema changes or deployment were performed.

### Native working-preference matching — October 7, 2026
The realtor directory now includes a five-answer matching questionnaire using published service areas and the shared web ranking function. Results show explicit eligibility/style reasons and preference points; changing an answer clears prior results. Matching is optional and the full directory remains visible. Answers remain screen-local; no preference storage is implied. Focused component checks verify completeness gating, exact-match scoring and changed-answer/no-eligible states. Introduction requests, optional consented preference persistence and signed-device acceptance remain open.

### Native realtor introduction intake — October 7, 2026
Published directory profiles and matching results now expose the verified-account enquiry form for realtor introductions. The shared native validator requires exactly one property or realtor target and the existing submit RPC receives that exact frozen target. Property enquiry behavior remains covered; tests now verify realtor-only parameters and reject mixed targets. Matching answers are not automatically included in the message or stored. Optional preference persistence and signed-device/live intake acceptance remain open. No actual enquiries or deployment occurred.

### Native optional preference transport — October 7, 2026
Implemented strict working-preference validation, private owner-scoped retrieval and revision-controlled save/delete through the existing audited RPC. Save requires explicit consent; confirmation requires matching stored revision/content (or actual absence after deletion) and fresh verified identity. Transport/malformed/changed-readback outcomes remain uncertain and require stored-state recovery rather than blind resubmission. Focused helper tests pass. Native preference controls and device acceptance remain unfinished; no preferences, schema or deployment were changed externally.

### Native matching preference controls — October 7, 2026
Implemented explicit stored-state check, load saved answers, consented save and delete controls in the native matching questionnaire. Verified identity gates private actions; checking is required before writes, unknown outcomes disable writes until a fresh check, and loading saved answers clears prior ranking results. Duplicate actions and late unmounted responses are suppressed. Existing roster/matching/storage helper checks pass. Component interaction and signed-device acceptance remain open; no actual preference records or deployment were changed.

### Native preference control interaction verification — October 7, 2026
Focused component checks found and fixed an old-handler bypass of the uncertain-write guard: a response generation now invalidates previously captured mutation callbacks after stored-state checks, successful writes and uncertain outcomes. Tests cover consent/check gating, duplicate actions, frozen uncertainty, explicit recovery/load/delete and unmount suppression. Native realtor checks, TypeScript and lint pass. Real signed-device/cross-account database acceptance remains open.

### Native owned application list — October 7, 2026
Added account navigation and a paginated list of the verified owner's stored rental applications. Queries use exact counts, 25-row pages, stable timestamp/id ordering and a minimal projection; strict row/count validation and fresh identity before/after prevent misleading or stale results. Screen distinguishes errors, no records and changed-positive pages and displays recorded status without equating approval with lease/tenancy activation. Focused helper verification passes. Application submission/detail/shared history/actions/private attachments and signed-device acceptance remain unfinished. No customer records, schema changes or deployment occurred.

### Native application submission transport — October 7, 2026
Added immutable validated application attempts with strict calendar dates, household bounds, contact/message limits and review consent. Existing audited submission RPC is followed by exact owner-scoped stored status readback and fresh verified identity. Known initial database rejection is distinguished from uncertain transport/malformed/readback outcomes. Focused validation, RPC parameter and transport checks pass. Native submission UI, detail/history/actions and signed-device acceptance remain unfinished; no customer application or deployment occurred.

### Native rental application intake — October 7, 2026
Published rental property detail now offers verified-account application intake with bounded contact/message fields, household size, strict move-in date and explicit review consent. Frozen secure references preserve uncertain retries; duplicate/completed actions and unmounted responses are suppressed. Confirmation displays recorded application status and explains that approval does not activate a signed lease/tenancy. Stored-application navigation supports recovery. Validation errors remain correctable rather than freezing an unsent form. Focused helper/component checks pass. Detail/history/actions/private attachments and signed-device acceptance remain unfinished; no real customer application or deployment occurred.

### Native application detail/shared history — October 7, 2026
Application list now links to an owned native detail screen with stored status, household/move-in/message and count-first 25-row shared review history. Explicit applicant ownership is checked before child history reads; fresh identity brackets the flow. Strict response checks, minimal projections and stable ordering protect against malformed/stale results. Loading/error/unavailable/empty/changed-history and refresh states are implemented. Focused ownership/history pagination checks pass. Reply/withdraw actions, private document/co-signer/lease flows and signed-device acceptance remain unfinished; no actual applications or deployment were changed.

### Native application owner-action transport — October 7, 2026
Implemented immutable reply/withdraw attempts with strict request/version/reason validation, fresh verified account checks and explicit ownership before the role-aware transition RPC. Confirmation requires exact owner-scoped stored status/version readback. Known initial rejection is distinct from uncertain transport/malformed/changed-confirmation outcomes. Focused tests cover owner binding, prohibited staff actions, version/reason bounds and readback mismatches. Native action controls and signed-device acceptance remain unfinished; no customer application or deployment was changed.

### Native applicant reply/withdraw controls — October 7, 2026
Application detail now offers reply/resubmit at needs-info and withdrawal at eligible stages. Required shared message/reason, explicit withdrawal confirmation, secure reference/version freezing, duplicate/completion/unmount guards and current-history recovery are implemented. Focused component tests check uncertain retry preservation even after later known rejection, completion, refresh and unmount suppression alongside transport checks. Signed-device/backend acceptance and private supporting journeys remain open. No real application, deployment or schema change occurred.

### Native private document metadata preparation — October 7, 2026
Added applicant-owned, count-first 25-row uploaded-document metadata retrieval. Application ownership precedes child reads; fresh verified identity brackets queries. Explicit metadata projection omits object paths, hashes, signed URLs and internal review evidence. Strict row/count checks reject malformed/duplicate results. Focused helper tests pass. Native document screens, secure uploads/downloads, co-signer/lease flows and device acceptance remain unfinished; no actual documents/storage/deployment were changed.

### Native supporting-document screen — October 7, 2026
Application detail now links to an applicant-owned supporting-document screen with exact-count pagination, filenames/kinds/submission times, loading/error/empty/changed-record states and explicit refresh. Uploaded metadata is not presented as approval. The screen does not fetch private object paths or signed URLs. Focused document metadata/application checks pass. Secure upload/download controls, co-signer/lease flows and signed-device acceptance remain unfinished; no actual files, schema changes or deployment occurred.

### Native private download transport — October 7, 2026
Implemented document-download preparation with verified applicant/parent/document ownership, uploaded-state scope and existing private Storage signing. Signed URLs expire after 120 seconds and must use HTTPS, the exact Open House Supabase host, the expected bucket endpoint and a nonempty token; identity is rechecked before returning access. Focused helper tests pass. Native open/download controls, live Storage/device acceptance, uploads and supporting co-signer/lease journeys remain unfinished. No actual files or signed customer URLs were created.

### Native private document opening — October 7, 2026
Uploaded-document cards now prepare a fresh owner-verified 120-second signed link and explicitly hand it to the device browser. Duplicate taps are locked, provider/device failures are controlled and late handoff is suppressed after unmount. UI reports browser handoff rather than claiming download completion. Focused component checks verify fresh links, errors and unmount behavior. Live Storage/device acceptance, secure uploads and co-signer/lease flows remain open. No customer signed links/files or deployment were created.

### Native document withdrawal — October 7, 2026
Uploaded document cards now offer explicit withdrawal/keep controls and same-document retry/refresh recovery. The helper verifies parent/document ownership, invokes the existing audited withdrawal RPC and confirms stored withdrawn state before success. Duplicate/completed actions and unmounted responses are suppressed. Withdrawal is described as removal from active review, not immediate physical deletion. Focused transport checks pass; component/device and live Storage acceptance remain open. Native uploads additionally require a bearer-authenticated trusted-server certification path; the current web endpoint is cookie-authenticated. No actual documents or deployment changed.

### Native document withdrawal interaction verification — October 7, 2026
Focused component verification now covers explicit confirmation, duplicate lock, same-document retries, continued uncertainty after later rejection, confirmed result/refresh and unmount suppression. The current migration's applicant SELECT policy permits owned withdrawn metadata, supporting authoritative withdrawal readback; live deployed/device acceptance remains open. No external document changes occurred.
Broad checkpoint verification: all 52 automatic groups passed; Expo web/Android/iOS exports completed. These are bundle/code checks, not signed-device or live-provider acceptance. Full production completion remains unproven.

### Native trusted-server identity preparation — October 7, 2026
Added a server-only native bearer authentication helper. It validates explicit bounded JWT-shaped authorization, verifies the token with Supabase getUser, requires confirmed non-anonymous identity and constructs a per-request publishable-key client carrying that bearer for RLS. Configuration is bound to the Open House project; credential/transport failures are distinguished from rejected sign-in. Focused authentication checks pass. The native document certification route and upload/device/live Storage acceptance remain unfinished. No server secrets or external records changed.

### Native upload certification endpoint — October 7, 2026
Added bearer-authenticated native document reserve/finish endpoint. It checks parent/applicant ownership, validates bounded file/category input, uses existing reservation/private signed-upload permissions, verifies retrieved byte size/signature and computes server SHA-256 before trusted certification. Stored uploaded state is read back; unknown failures remain private/no-store uncertain responses. Focused endpoint checks cover auth/credential gates, reservations, malformed outcomes, invalid bytes and successful certification actor/hash. Native picker/upload controls and actual Storage/device acceptance remain unfinished; trusted-server credentials still gate live operation. No real files or deployment occurred.


### Native upload transport checkpoint
Implemented separate reservation, exact-byte signed storage upload and trusted certification helpers. Requests require fresh verified identity and a matching session, use HTTPS without redirects, preserve the request UUID and prohibit overwrite. Focused transport checks and native type checking pass. No live file was uploaded. Picker, recovery UI, device acceptance and production activation remain open; canonical application URL and server credential are required. Full production goal remains active.


### Native document picker and recovery checkpoint
Added SDK 57 system document selection, an 8 MB limit, byte-size and format screening, explicit sharing confirmation, a stable in-memory reservation, and certification recovery after uncertain storage delivery. Duplicate actions are locked; storage retries prohibit overwrite. Successful certification requires an explicit document-list refresh. Selected bytes are not persisted for restart recovery. Upload activation remains gated by the canonical HTTPS application URL and trusted server credential; actual device, live Storage and restart recovery acceptance remain open. Native typecheck/lint and focused interaction checks pass.

Verification: native application/document test suite passes, including picker uncertainty recovery. SDK 57 exports complete for web, iOS and Android after adding the shared document helper directory to Metro watch folders. These are JavaScript/Hermes exports, not signed device builds or live upload acceptance.


### Native stored-reservation recovery checkpoint
The application document screen now loads unfinished reservations from the database independently of the selected file memory. It verifies the current applicant and parent ownership, filters the owner and reserved state explicitly, fetches only display metadata, validates expiry/category and paginates 25 at a time. Users can check trusted certification of a file already in Storage or withdraw the same reservation and choose a replacement. No signed token, local URI or document bytes are persisted for restart recovery. Dedicated metadata and certification-control tests pass, including same-document retries and duplicate/unmount guards. Actual device restart and live Storage acceptance remain pending; production goal remains active.

Recovery checkpoint verification: native type checking and lint pass; reservation metadata and certification-control checks pass; Expo export completes for web, iOS and Android. No actual private document, signed device build or deployment was created.


### Native password sign-in checkpoint
Sign-in now validates input bounds, requires a returned session, verifies the same confirmed non-anonymous actor remotely and verifies that identity again after context refresh before navigating. Unconfirmed local sessions are explicitly signed out with failure handling. Screen actions suppress duplicate taps, completed retries and late unmounted responses. Focused helper and interaction checks pass. Native registration, email verification, recovery/deep links and actual device Auth acceptance remain open. No live account or email was created.


### Native registration and confirmation checkpoint
Added prospect registration with explicit account-creation confirmation and a 12-character minimum password, generic email-check feedback, duplicate/mounted guards and unexpected-session closure. Native Supabase uses PKCE with existing encrypted storage; confirmation exchanges a bounded code and verifies the same confirmed, non-anonymous actor. Redirect: `openhouse-realty://auth/confirm`. Activation requires that exact Supabase Auth allowlist entry, production SMTP and a built app handling the scheme. Expo Go, actual mail/deep-link and signed device acceptance remain open; no live account/email or provider configuration was created. Password recovery and confirmation resend remain next.

Registration checkpoint verification: focused account/sign-in/registration helper checks, native type checking and lint pass. Expo exports complete for web, iOS and Android. These exports do not prove live email, callback routing on installed devices or production Auth configuration. Existing-session registration is rejected before signup.


### Native confirmation resend checkpoint
Added signup-confirmation resend from mobile sign-in, exact native redirect, normalized email validation, existing-session rejection, generic delivery feedback, duplicate lock and one-minute cooldown. Installed auth-js resend implementation was inspected: PKCE resend creates a new verifier, so the interface instructs use of the newest link on the initiating device. Helper/control/sign-in regression checks and native typecheck/lint pass. Live SMTP/deep-link/device activation remains pending; password recovery is next. No live email was sent.


### Native password recovery implementation checkpoint
Added bounded, session-free recovery email requests, one-minute request cooldown and native callback `openhouse-realty://auth/recover`. Callback exchanges PKCE code and requires the installed SDK recovery redirect marker plus fresh confirmed identity. Password update binds the recovered actor, requires matching 12-character inputs, freezes uncertain updates for same-password retry and separates accepted update from local sign-out uncertainty. Recovery helper/request interaction tests pass. Full reset-form/callback interaction, platform export, actual mail/device and production Auth acceptance remain open. No live email/account/password was changed.


### Native password recovery interaction checkpoint
Recovery callback and reset-form interaction checks now cover failed confirmation withholding password controls, mismatched/short passwords making no request, duplicate locks, same-password retry after uncertain delivery despite stale input edits, accepted password updates with separate local sign-out uncertainty, completion locks and unmount suppression. Fixed unconfigured Auth feedback so it does not remain indefinitely on verification. Native application/account/document regression suite, type checking and lint pass. Actual SMTP/installed-device/restart/expired-link acceptance remains pending. Full production objective remains active.

Recovery verification export: web, iOS and Android JavaScript/Hermes exports complete successfully. No signed binary, live recovery email or account mutation was performed.


### Native co-signer invitation read checkpoint
Added verified recipient-only invitation detail and count-first 25-event history. Applicant/staff preview permissions are not mistaken for recipient consent rights; unclaimed invitations must remain pending and unexpired. The existing availability RPC supplies current review eligibility. Display data excludes recipient email, organization and actor internals; rent retains its decimal string and is formatted with BigInt. Focused access, redaction, validation, history and changed-identity checks pass. Native consent/decline/withdrawal controls, invitation discovery/handoff, device and live participant acceptance remain open. No invitation, consent or legal guarantee was created.


### Native co-signer decision implementation checkpoint
Added recipient accept/decline/withdraw controls with explicit participation consent, separate confirmation and no legal-guarantee claim. Helper verifies fresh invited identity, rejects applicant/staff previews, sends stable request UUID and expected version through existing RPC, checks recorded state/version under recipient scope and revalidates the actor. Unknown outcomes freeze the original request/decision and retain uncertainty through later rejections. Decision helper/read regression tests and native typecheck/lint pass. Full interaction acceptance, native invitation discovery/handoff, platform export and actual signed participant/device verification remain open. No real consent or guarantee was created.


### Native co-signer interaction and entry checkpoint
Focused decision interaction tests pass explicit accept-consent gating, duplicate locks, stale action/checkbox callback suppression, frozen retries through later rejection, recorded result/refresh, accepted-consent withdrawal and unmount handling. Added a home entry accepting an invitation UUID or HTTPS `/cosigners/<uuid>` link. It extracts only the identifier and navigates internally; supplied hosts are never fetched. Invalid/insecure/credential-bearing links are rejected. Recipient permissions remain enforced by fresh identity, RLS and the workflow RPC. Automated email-to-installed-app handoff, signed participant/device acceptance and applicant invitation controls remain open. No real invitation decision was sent.

Co-signer entry/interaction export checkpoint: web, iOS and Android JavaScript/Hermes exports complete. UUID predicate typing corrected; native type checking passes and dedicated decision/link tests pass. These checks do not prove live recipient/device acceptance or automated email handoff.


### Native applicant co-signer register checkpoint
Added applicant-side invitation register linked from application review, with verified current identity, explicit parent/application ownership before child reads, applicant predicates on count and row queries, minimal displayed fields and stable count-first 25-row pagination. Stored status/expiry/reference and invited email are available to the owning applicant; no organization/internal fields are projected. Focused helper tests cover ownership, redaction, invalid metadata/counts, empty/changed results and identity changes. Native type checking and lint pass. Applicant invite/revoke controls, their interaction acceptance, live participant/device and provider handoff acceptance remain open. No real invitation was created.


### Native applicant invitation creation checkpoint
Added applicant co-signer invite form with explicit sharing permission, disclosed preview fields, normalized recipient email and immutable request UUID. Helper verifies current applicant and owned application before invoking the existing invitation RPC, checks stored id/application/applicant/email/request and recorded state/version, and revalidates identity. Unknown outcomes freeze recipient and permission/request for retry; confirmed receipt does not assert email delivery or consent. Focused invite/register helper tests, native type checking and lint pass. Form interaction acceptance, applicant revocation, full platform exports and live provider/device/participant acceptance remain open. No real invitation or email was created.


### Native applicant invite/revoke interaction checkpoint
Added version-bound applicant revocation for pending/accepted invitations with explicit confirmation and parent/child ownership checks before the existing RPC. Stored revoked state/version and current actor are required before receipt. Invite-form and revoke interaction checks pass permission/confirmation gates, duplicate locks, stale input protection, frozen retries through later rejection, accepted-state receipts, explicit refresh and unmount suppression. Helper checks verify exact RPC/readback scope and unknown outcome handling. Native type checking and lint pass. Live participant/device/email acceptance, automated handoff and broader platform verification remain open. No real invitation or consent was changed.


### Full account/document/co-signer regression checkpoint
All 52 verification groups pass, including native auth, signup/resend/recovery, upload/reservation recovery, recipient decisions and applicant invitation/revocation. Expo exports complete for web, iOS and Android. These are automated fixture/component checks and JavaScript/Hermes exports; they do not establish live email, Storage, installed-device, provider or signed cross-role acceptance. Next dependency-ready work is native shared applicant lease summaries and review/questions via existing authorized RPCs. The seven-milestone production definition and external release gates remain unchanged. Web production build verification is running.

### Native applicant lease-summary checkpoint — 2026-10-07

- Added an ownership-gated native shared lease-summary history, linked from application review. It reads the existing applicant RPC, applies the actual web date/version/money validators, explicitly removes non-shared fields, and offers count-first bounded pagination and refresh. A count change after page clamping is rejected rather than presenting a misleading page.
- Added exact TypeScript aliases and Metro watch directories for the pure shared lease/enquiry validators. Installed the exact native TypeScript import resolver to restore full import linting.
- Verification: production web build passed (71 static pages generated), native typecheck and lint passed, focused lease-summary helper verification passed. The new all-platform Expo export is still running; do not claim its success until its live process returns. Earlier complete suite remains 52/52 groups passed.
- Next: native summary review/questions and staff response history using existing RPCs, then remaining native role journeys and the other full-plan milestones. No live records, email, signing, payments, deployment or production activation occurred.

### Native summary conversation checkpoint — 2026-10-07

- Prior summary-history lint and iOS/Android/web Expo exports completed successfully.
- Added native applicant conversation history using the existing lease_summary_review_history RPC and actual shared web parser. Owned application, applicant role and exact draft identity are required; summary/event fields are explicitly projected to exclude private extras. Includes current/historical distinction, empty/error states, bounded pagination and navigation from the shared summary register.
- Added a frozen applicant response helper with the existing review_rental_lease_summary RPC. It accepts only reviewed/question actions, requires explicit review-only acknowledgment, retains request identity, verifies the stored event and fresh actor before confirming, and distinguishes known rejection from an uncertain write. Native submission controls remain next.
- Focused tests passed for ownership-before-RPC, role/draft validation, malformed history, field redaction, paging, frozen request validation, exact RPC nonce, stored message/reference mismatch and uncertain versus definitive rejection. Native typecheck passed. Final lint and new conversation platform export are running; live export session 6498 must be checked rather than restarted on silence.
- Remaining full development scope and external launch gates are unchanged. No live account, customer data, messages, signatures, payments or production activation occurred.

### Native applicant summary responses — 2026-10-07

- Added applicant question/review controls with explicit review-only acknowledgment, current-summary gating, awaiting-staff-reply gating, bounded questions, duplicate-tap protection and frozen request identity after uncertain outcomes. A later definitive rejection does not erase an earlier uncertain attempt. Confirmed receipts require helper stored-event verification; refreshed history remains the record.
- Added hook-level verification for acknowledgment-before-RPC, duplicate taps, stale edit callbacks, same-response retries, later rejection preservation, completion/refresh, empty-message reviewed action and unmount behavior. Focused tests and native typecheck passed.
- Prior conversation lint passed. Export session 6498 terminated with a missing-new-component resolution error after source files changed during its run; the component is present and a fresh export of the stable tree is running. Do not record this as a successful export. Final lint and stable-tree platform export remain pending. No live responses or emails were sent.

### Native lease control verification and next role scope — 2026-10-07

- Final native lint completed successfully. Focused control verification also checks historical-summary suppression, awaiting-question suppression and repeated-review suppression while retaining the question option after a recorded review.
- Full regression suite and stable-tree all-platform Expo export remain running (sessions 43408 and 5583 respectively). Re-poll these actual handles; do not restart merely because they are quiet.
- Next dependency-ready implementation is the native contractor workspace: verified active contractor registrations, scoped/count-first work-offer register and exact offer scope, followed by versioned accept/decline/release, current visits and separately authorized entry. Existing web tables/RPCs are the source of authority. Acceptance alone must not authorize a visit or entry. Completion reports/private evidence follow the shared web lifecycle.
- Full plan milestones, provider/business inputs, signed-in/device acceptance and production release gates remain open.

Stable-tree native lease-review export session 5583 completed with exit 0: web 915 modules, iOS 1278 modules, Android 1413 modules. Final native lint and typecheck also passed. This verifies bundling, not signed-device/provider/live-record acceptance. Full regression session 43408 remains live and must be polled to its terminal result.

### Native contractor register — 2026-10-07

- Full regression suite session 43408 completed: 52/52 groups passed, including the native lease history/response helper/control tests.
- Added a native contractor work register linked from the account home, with active verified registration gating, count-first registration pagination, scoped work-offer count/25-row pages, state filters, minimal shared projection, status/expiry display and separate no-registration/empty/error states. Rechecks registrations and fresh identity before returning. Acceptance, visit scheduling and entry authorization remain separate.
- Focused tests pass for active owner predicates, offer registration scope, state filter, clamped pagination, field redaction, revoked registration, changed actor, invalid records and empty versus missing access. Native typecheck passed. Final lint/export remain pending for this new register.
- Next: native offer detail and versioned response controls, then visit/entry/completion/evidence journeys. Full platform scope and external launch gates remain active. No live records changed, emails sent or deployment performed.

Contractor register final lint found an impure Date.now render expression. Corrected by computing the displayed expiry snapshot in the data loader, refreshed explicitly with the register. Focused tests and rerun lint passed. Corrected typecheck and platform export session 28732 remain to be polled; no export success is claimed yet.

### Native contractor offer detail — 2026-10-07

- Contractor register export session 28732 completed successfully for web/iOS/Android. Corrected register typecheck also passed.
- Added scoped native work-offer detail linked from each register item. It validates exact offer/registration binding, version/state/expiry and approved shared text, rechecks active contractor access and verified identity, and explicitly projects only the shared display fields. Includes unavailable/error/refresh states and scope/company/trade/version/expiry display.
- Extended focused tests cover detail registration predicates, shared projection, foreign contractor rejection, invalid version/state/scope and missing offers. Tests and native typecheck passed. Final lint and detail platform export are running.
- Next: versioned accept/decline/release controls, existing current visits and separate entry authorization; completion/evidence follow. Full production plan remains active, with no live changes, emails or deployment in this cycle.

### Native contractor response helper — 2026-10-07

- Offer-detail lint and all-platform exports session 14256 passed.
- Added frozen native accept/decline/release helper using the actual web workOfferInput validator and existing manage_contractor_work_offer RPC. Contractor role allowlist prevents management actions/scope edits. Active scoped access precedes writes; exact recorded RPC id/version/state is required, followed by a fresh scoped current offer read. Retry receipts retain the recorded outcome separately from later current state. No private management audit reads are attempted.
- Focused tests passed for actual shared validation, scope injection rejection, frozen nonce, no-access-before-RPC, exact receipt, later transitions, mismatched stored current state and definitive versus uncertain errors. Final helper lint/typecheck are running.
- Native response UI remains next, followed by current visits and entry authorization. No live assignments or messages changed. The full production objective remains active.

### Native contractor response controls — 2026-10-07

- Response helper final lint/typecheck passed. Added a single native response control to offer detail: accept/decline for open unexpired offers, release for accepted offers, a bounded reason, review-before-confirm, duplicate-tap guard, immutable request retries after uncertain outcomes and recorded-versus-current state receipt. Confirmation explicitly does not authorize a visit or entry.
- Focused hook tests passed for confirmation-before-write, duplicate taps, stale edits, frozen action/reason/nonce retries, preservation after a later definitive rejection, receipt/refresh, release action, expired/closed suppression and unmount. Native typecheck passed. Final control lint and all-platform export are running.
- Next: actual current visit and entry-permit read journeys, versioned visit responses and completion/private evidence. No live offer responses, emails or production activation occurred. Full development scope and external launch gates remain active.

### Native contractor appointment and permit view — 2026-10-07

- Contractor response control lint passed. Its export session 9173 failed because Metro did not watch the actual shared staff validator directory; added that directory without introducing web dependencies into native resolution. A new export is required and pending.
- Added native current appointment/entry-permit reader and view for accepted offers. Requires scoped active offer, exact contractor/offer/visit bindings, validated state/version/times, visit duration within eight hours and permit window within its visit. Shared fields are explicitly projected; assignment is rechecked after reading. Displays proposed/confirmed appointments and upcoming/current-at-check/expired permit windows with refresh and property-security verification copy.
- Focused tests passed for bindings, private-field exclusion, interval validation, revoked/foreign records, missing visits/permits and changed assignment. Native typecheck passed. Final lint and all-platform export remain pending.
- Next: versioned visit confirm/decline/cancel controls and retained history, then completion/private evidence. Full production goal remains active. No live appointment, permit or offer changed.

### Native contractor visit response helper — 2026-10-07

- Added frozen native confirm/decline/cancel helper using the actual web visitInput validator and manage_contractor_visit RPC. Assignment/visit/contractor binding and fresh scoped access precede writes. Responses cannot modify the approved visit window. Exact recorded acknowledgment plus current scoped visit read are required, with recorded and later current states kept separate. Known rejections are distinguished from uncertain writes.
- Focused tests passed for shared validator, proposal/window injection rejection, frozen nonce, owner/assignment gates before RPC, recorded-versus-later state, receipt mismatch and uncertainty. Native typecheck passed. Final lint session 91285 and previous stable-tree view export session 36399 remain running. New helper is not yet wired to the native view; UI controls are next.
- Remaining contractor history/completion/private evidence and full platform milestones remain active. No live visit, email or deployment occurred.

Contractor appointment/permit view export session 36399 completed successfully for web, Android and iOS. This also verifies the prior response-control shared staff-validator Metro fix. Native visit response controls remain next.

### Native contractor visit response controls — 2026-10-07

- Visit helper lint passed. Added native confirm/decline/cancel controls to the current appointment view, with reason, review-before-confirm, duplicate guard, stale-edit guard, frozen retry payload after uncertain writes, and recorded/current response receipt. Confirmation is omitted for started proposed visits; confirmed appointments offer cancellation. Database authorization/conflict/progress rules remain authoritative.
- Native typecheck and lint passed. Focused hook verification covers duplicate taps, review-before-write, frozen retries after later rejection, completion/refresh, decline/confirm/cancel selection, started/closed suppression and unmount. All-platform export is running.
- Next: retained contractor appointment history, then completion reports/private evidence and the remaining native roles/full milestones. No live visit responses, emails or deployment occurred. Full production goal remains active.

### Native retained contractor appointments — 2026-10-07

- Native visit-control export session 28524 passed for web/iOS/Android.
- Added retained appointment reader and screen linked from offer detail, including proposed/confirmed/declined/cancelled records. Owned active assignment access is checked before and after; count-first pages contain at most 25 explicitly shared records. Status/version, Jamaica time, shared note and reference remain visible after cancellation/decline. This is an appointment register, not private management event history or entry authority.
- Focused tests passed for owner/assignment predicates, pagination, shared projection, invalid records, changed/revoked access and genuine empty state. Helper typecheck passed. Final screen typecheck/lint and history platform export are running.
- Next: completion report and shared feedback journeys, then private contractor evidence and remaining role/full platform milestones. No live records, emails or production deployment changed.

### Native completion reader and completed-state correction — 2026-10-07

- Retained-history lint and all-platform export session 87008 passed.
- Inspecting the deployed completion schema revealed completed offer/visit states missing from native allowlists. Corrected offer register/detail/filter, retained visit history and visit-response readback to preserve access after management-approved completion. Regression tests now explicitly cover completed offer/detail and retained visits.
- Added count-first 25-row native completion-report reader with assigned active access before/after, exact contractor/offer bindings, schema text/state/version validation and explicit shared work/tests/outstanding-items/review projections. No management actor/internal fields returned. Focused completion and affected offer/history/visit-response tests passed.
- Final lint/typecheck sessions 43663/41153 are running. Completion report UI/submission and private evidence remain next; full production scope/launch gates remain active. No live records or notifications changed.

### Native completion report history screen — 2026-10-07

- Added count-first paginated native completion history linked from assignment detail, with work performed, test results, outstanding items, shared management feedback, status/revision and submission time. Includes ownership gating, unavailable/error/empty/changed-record states, refresh and return navigation. Submitted reports are distinguished from management-approved completion/payment.
- Tightened report reader invariants: submitted reports have no management review; reviewed states require bounded shared feedback. Focused tests cover invalid review-state combinations alongside existing scope, pagination and access cases. Screen typecheck passed; focused test, final lint and all-platform export remain to be checked to terminal.
- Next: exact shared submission validator/RPC, departure/pending-report/evidence readiness, immutable uncertain retries and submission controls; private evidence follows. Full production goal/launch gates remain active. No live report or email was submitted.

### Native completion submission helper — 2026-10-07

- Completion-history export session 82841 passed for web/iOS/Android.
- Added frozen contractor submit helper using actual web completionInput and existing manage_completion_report RPC. Active assigned access precedes writes; management fields/actions are excluded. It verifies exact submitted receipt and immutable stored report contents under offer/actor predicates, and rechecks active access before success. Original submission receipt remains separate from later management-reviewed state. Retries preserve the original request and can reconcile after review.
- Focused tests passed for shared validation, management-field rejection, frozen payload, own access before RPC, exact nonce, stored evidence mismatch, foreign actor, invalid acknowledgment, later approval and uncertain versus known rejection. Native typecheck passed; final lint session 76174 remains running.
- Native submission UI and departure/pending/evidence-readiness presentation remain next. Database departure, current work revision, pending report and frozen uploaded evidence guards remain authoritative. Full production scope remains active; no live report/notification was sent.

### Native completion readiness — 2026-10-07

- Submission helper final lint passed. Added scoped completion readiness reader and presentation in completion history: pending reports, on-site presence, departure records, proposed appointments and uploaded/reserved evidence counts. Count validation and fresh assignment revision check prevent false success on errors or changed work. Basic preparation readiness is explicitly distinguished from authoritative RPC acceptance.
- Shared-file presentation explains that only verified uploaded files enter the immutable report snapshot; unfinished reservations are excluded. File review/upload and report submission controls remain next.
- Focused readiness tests passed for actor/assignment predicates, pending/on-site/no-departure/proposed gates, malformed counts and assignment revision changes. Helper typecheck passed. New presentation typecheck/lint sessions 38606/33051 are running; helper lint session 77865 also must be checked. No live file/report/notification was created. Full production goal remains active.

### Native contractor evidence register — 2026-10-07

- Completion-readiness presentation final lint passed. Added a private contractor evidence metadata register linked from assignment/completion pages, with count-first 25-row pagination, reserved/uploaded status, file name/type/size, reservation expiry, fixed-to-report status and empty/error/refresh states. Storage paths, hashes, actor fields and signed URLs are excluded.
- Reader checks active assigned access before/after and exact offer/user/file/report-link bindings. Focused tests passed for scope/paging, private-field exclusion, malformed/frozen-link metadata, changed/revoked access and empty state. Helper typecheck passed; final screen typecheck/lint are running.
- File opening, upload/certification/recovery/withdrawal and report submission controls remain next. Metadata visibility alone does not complete evidence review. Full production scope remains active; no private file/report/email was created or sent.

### Native private evidence opening — 2026-10-07

- Evidence register all-platform export session 10494 passed. Added 120-second signed evidence download helper with active assignment and exact actor/file/state binding, exact configured Supabase host/bucket/object validation, credentials/fragment rejection, and fresh file/access rechecks before device handoff. No signed URL enters register metadata.
- Added uploaded-file open controls: duplicate guard, fresh signed link on each retry, controlled handoff result and no handoff after unmount. Confidential downloaded-copy guidance retained.
- Focused download and control tests passed for owner scope, TTL, malformed host/path/token, withdrawn/foreign evidence, duplicate taps, fresh retry links, failure recovery and unmount. Helper typecheck passed; final screen lint/typecheck and new open-control platform export remain pending.
- Next: private upload/certification/recovery/withdrawal and completion submission controls, followed by remaining native/full platform scope. No live file, signed URL or report was generated.

### Native contractor evidence withdrawal — 2026-10-07

- Private evidence-open lint/export session 59597 passed for web/iOS/Android. Added exact owner/assignment evidence withdrawal helper using existing withdraw_contractor_evidence and stored withdrawn-state confirmation. Already-withdrawn records reconcile without an unnecessary mutation. Fresh active assignment access is rechecked before success.
- Added explicit withdrawal confirmation controls with duplicate lock, same-file retries, controlled uncertainty, refresh and unmount suppression. Withdrawal does not promise immediate file deletion. Controls only appear for non-frozen files on accepted assignments; database mutable/frozen guards remain authoritative.
- Focused helper/control tests passed for owner binding, already-withdrawn recovery, known frozen rejection, invalid acknowledgment/readback, confirmation gate, duplicate taps, retries, refresh and unmount. Helper typecheck passed. Final integration typecheck/lint are running; withdrawal platform export is pending.
- Next: native evidence upload/certification/recovery and report submission controls, then remaining full-platform work. No live evidence or report changed. Full production goal remains active.

### Native contractor evidence reserve/certify endpoint — 2026-10-07

- Evidence withdrawal final lint and all-platform export session 70126 passed.
- Added bearer-only native evidence reserve/finish endpoint using existing reserve_contractor_evidence/finish_contractor_evidence RPCs. Explicit active contractor/assignment access, bounded JSON, shared file validation, non-overwriting signed upload reservation, stored size/signature/hash certification, fresh actor check before trusted RPC and stored uploaded readback. Responses are private/no-store; absent server credentials return a truthful configuration gate.
- Focused API tests passed for identity/configuration gates, reservation/retry states, malformed acknowledgment, invalid bytes with no admin certification, revoked contractor registration and changed identity before certification. Root TypeScript passed. Production web build session 73209 is running; inspect the same live handle to terminal.
- Native upload client/control and reservation recovery remain next, then report submission controls. No live evidence upload/certification or notification occurred. Full production objective remains active.

### Native contractor evidence upload client — 2026-10-07

- Added native reserve/upload/certify client with actual shared file validation, frozen assignment/request/file metadata, secure HTTPS-origin and redirect-rejecting bearer transport, fresh confirmed nonanonymous identity, active assignment checks, non-overwriting signed storage upload and exact-byte-size check. Finish requires exact own assigned evidence before calling native certification and validates exact uploaded acknowledgment. Storage send/certification remain separate for safe uncertain-upload recovery.
- Focused tests passed for file validation, secure bearer transport, stable request identity, exact bytes, no overwrite, certification and identity gates. Native typecheck passed; final client lint session 58090 remains running. Web production build session 73209 remains live and has been polled without restart.
- Native file-picker/control and reservation recovery remain next, followed by report submission controls/full platform milestones. No live upload/certification, private bytes or email was sent. Full production goal remains active.

### Native contractor evidence picker and upload controls — 2026-10-07

- Added evidence picker/confirmation flow linked for accepted assignments: single PDF/JPEG/PNG up to 8 MB, actual-byte/signature validation, temporary native cache cleanup after reading, frozen request/file bytes in memory, no writes until confirmation, duplicate guard, reserve-before-storage, non-overwrite upload and separate certification. Unknown storage outcomes retain the request and offer check/finish without byte retransmission. Completion and unmount guards prevent further writes/handoffs.
- Focused control tests passed for explicit confirmation, duplicates, stable reservation after uncertain storage, certification-only recovery and completion guard. Initial component typecheck passed. Previous helper lint found import order; corrected it. Final integration typecheck/lint sessions 55348/18248 and export session 90099 remain pending. Web build session 73209 is still live and has not been restarted.
- Restart reservation recovery, private upload/certification live acceptance and report submission controls remain next, plus the full original platform milestones. No live file/report/email was sent. Production goal remains active.


### Native contractor evidence recovery checkpoint

Added an explicit certification action to unfinished, unfrozen evidence reservations for accepted assignments. This uses the existing authenticated server verification of stored bytes and retains the same reservation when confirmation is unavailable; it does not require retaining private file bytes on the device after restart. Duplicate presses, completed actions and unmounted updates are guarded. The focused control test passes. The preceding upload integration passed native lint and all-platform Expo export. Final recovery typecheck, lint and export remain in progress; live Storage and device acceptance remain outstanding. Next: build the native completion submission review and confirmation control using the existing validated, idempotent helper.


### Native contractor completion submission checkpoint

Added the native completion report form beneath successful basic readiness checks, using the actual assignment revision and existing submission RPC helper. Contractors enter work performed, tests/results, outstanding items and a reason; review is required before any write. Submission retries retain the same immutable report and request reference after an uncertain response, including a subsequent known rejection. Stale edits, duplicate presses, completed actions and unmounted updates are guarded. Receipts distinguish recorded submission from the current management review and do not imply completion approval or payment. The focused control regression passes. Final integrated native checks and all-platform export are running. Evidence recovery separately passed native typecheck, lint and all-platform export; the Next production build passed with 72 static pages and the native evidence endpoint. No live device/Storage acceptance or production deployment is claimed.


### Native security entry lookup checkpoint

Added authenticated, exact-reference gatehouse permit lookup through the existing security_entry_snapshot RPC. Fresh confirmed, nonanonymous identity is checked before and after lookup; the returned shared projection validates permit/time/status and presence consistency, omitting unrelated private fields. Native account navigation now opens a permit reference form and approved property/company/work/instructions/status display with controlled missing-access and refresh states. It explicitly describes eligibility as a snapshot and does not claim recording arrival or departure. The focused helper test passes. Integrated typecheck/lint/export are running. Next: native presence arrival/departure review and confirmation through the existing independently authorized RPC, followed by retained presence history. Contractor completion submission separately passed TypeScript, lint, native regression suite and iOS/Android/web exports. Actual signed-in and device acceptance remains open.


### Native presence command foundation checkpoint

Implemented native arrival/departure command helper using the actual shared presence validator and existing independently authorized RPC. Arrival requires explicit identity attestation; departure binds the current presence to the permit and revision. Stable frozen payloads support existing RPC deduplication, and acknowledgments are checked against the current authorized permit snapshot, distinguishing recorded from later state. Focused tests pass for validation, permission failure before mutation, exact acknowledgment and uncertainty classification. The native confirmation control and screen integration are still next; this helper alone does not complete the security workflow. Typecheck/lint are running.


### Native presence confirmation checkpoint

Connected native security arrival/departure controls to authorized permit snapshots. Arrival requires an explicit identity attestation; both actions require a reason and review before recording. Duplicate/stale/completed/unmounted guards and frozen uncertain retries preserve the same action. The existing database independently rechecks authority, time window, current work and revisions. Focused control test and web/native TypeScript checks pass. Final lint and three-platform export are running. Shared pure security validation is now watched by Metro. Retained security presence history is next; live cross-role/device/concurrency acceptance remains outstanding.


### Native security retained history checkpoint

Added retained arrival/departure events beneath the authorized permit screen. The reader rechecks the independently authorized permit snapshot before and after reading, binds the presence parent to the exact permit, and filters history by exact presence/property. Reads count before deterministic 25-event pages; strict event validation and explicit projection exclude RPC payload/internal extras. The display includes action/state/revision, reason, actor reference and Jamaica time, with empty/changed/error/refresh/paging states. Focused history regression passes. Integrated native TypeScript/lint and three-platform export are running. Preceding presence controls passed lint and all-platform export. Live security/contractor cross-account, device and PostgreSQL 17 concurrency acceptance remain open. Next dependency-ready native shared-record journey: authorized owner portfolio, while resident activation remains dependent on approved signing/payment/tenancy inputs.


### Native owner portfolio checkpoint

Added approved owner portfolio using the existing scoped owner_portfolio_summary RPC and actual shared statement-date and exact BigInt money helpers. Native reader checks fresh confirmed/nonanonymous identity before/after, exact requested dates/currency, bounded canonical pagination, strict property projections, unavailable occupancy and income-minus-expense consistency. Tests pass including amounts beyond safe JavaScript integers, changed identity, malformed records and private-field exclusion. The native account links to a date-filtered property register with current unit/work counts, posted income/expense/net, paging and controlled error/empty/refresh states. Financial basis and unavailable occupancy are explicit. Integrated native typecheck/lint/export are running. Security retained history separately passed typecheck/lint and all-platform export. Actual owner-account/device acceptance and production financial reconciliation remain outstanding.


### Native management access foundation checkpoint

Implemented fresh verified-account management access using the actual own staff_accounts row, organization UUID, membership revision and approved admin/manager role. Realtor/finance or missing membership returns no management access; invalid/foreign records and changed or anonymous identity are rejected. Focused access tests pass; native typecheck/lint are running. Next: organization-scoped native management work queue and exact shared work detail with membership rechecks before/after reads. Owner portfolio separately passed native TypeScript, lint and iOS/Android/web export. A broader full regression suite is running; no terminal success is claimed yet.


### Native management work queue checkpoint

Added the organization-scoped native work queue with state filters, count-first deterministic 25-row pages, bounded/redacted rows and controlled empty/error/changed-record/refresh states. Fresh manager/admin membership is checked before/after reads; organization, role and membership revision must remain identical. Focused queue tests pass for filters, pagination, invalid/foreign records and membership changes. Native screen is connected from account navigation. Final TypeScript, lint and iOS/Android/web export are running. Exact work detail, triage and related management journeys remain next. The full production objective and live acceptance gates remain unchanged.


### Native management work detail checkpoint

Added exact organization-bound work detail and navigation from the native queue. Reader validates work state/revision, property and optional unit bindings and bounded shared fields, then rechecks unchanged manager/admin membership. The display includes issue details, priority/state/revision, managed location references, reporting actor/time and controlled missing/error/refresh states. Focused tests pass for foreign/invalid records, parent mismatches, missing records and changed access. Final native TypeScript/lint/export are running. Preceding work queue passed lint and iOS/Android/web export. Next: native triage/cancellation review controls and retained work audit; live authenticated/device acceptance remains open.


### Native management transition foundation checkpoint

Fixed a TypeScript nullable-unit response guard found in final detail verification. Added native triage/cancellation helper using the actual shared work-order validator and audited manage_work_order RPC, with fresh exact work access before mutation, immutable request payloads, strict revision/state acknowledgment and current authorized record confirmation. Focused tests pass for triage/cancel, permission denial before write, known/uncertain errors and recorded versus later states. Typecheck/lint reruns are active. Detail screen export passed all three platforms; this does not replace the pending typecheck repair verification. Next: review-before-confirm controls for triage/cancellation, then work audit history. Live management/device acceptance remains open.


### Native management triage controls checkpoint

Connected native work triage/cancellation review controls to exact detail records. Eligible reported/triaged records with a positive revision allow priority selection or cancellation with a reason, review and explicit confirmation. The controls guard duplicate, stale, completed and unmounted callbacks, retaining the same action/priority/reason/request after uncertain responses and subsequent known rejection. Receipt separates recorded decision from later work state; priority is not represented as a contractual SLA. Focused interaction test, native TypeScript and lint pass. Three-platform export is running. Next: retained work audit history and remaining assignment/scheduling/completion management journeys. Signed-in/device/live concurrency acceptance remains open.


### Native management work audit checkpoint

Added retained work-order event history beneath exact native detail records. Parent work access and organization membership are checked before/after reads, with unchanged organization/role/revision required. Events are filtered by exact work and organization, counted before deterministic 25-row paging, validated against stored action/state/priority/revision formats and projected without payload extras. UI shows transitions, priorities, decision reason, actor, revision and Jamaica time, with paging/empty/error/refresh states. Focused history tests pass; final native TypeScript/lint/export are running. Previous triage/cancellation export passed iOS/Android/web. Next: approved-contractor selection and work-offer management. Actual manager/device/live concurrency acceptance remains open.


### Native approved contractor directory checkpoint

Added organization-scoped active contractor directory under triaged native work detail. Reader uses fresh management membership before/after, count-first 25-row pages, approved company/trade validation and minimal projection. Focused tests pass for active/organization predicates, pagination, invalid/foreign records and changed membership. The directory displays approved trade coverage and references with paging/error/empty/refresh states; it does not yet create an offer. Final native typecheck/lint/export are running. Work audit previously passed native TypeScript/lint and all-platform export. Next: exact contractor selection, approved scope and work-offer creation/withdrawal. Live authenticated/device acceptance remains outstanding.


### Native exact contractor selection checkpoint

Added exact selected-contractor lookup with organization/id/active predicates, validated registration revision/company/trades and unchanged fresh management membership before/after. The directory can review, recheck and clear a selection without writing an offer. Focused tests pass for exact scope, foreign/inactive/invalid registration, duplicate trades and changed membership. Native typecheck/lint are running. Preceding directory export passed all platforms. Next: approved scope preparation and offer command/control; selecting a registration does not assign work. Live management/device acceptance remains open.


### Native approved work-offer command checkpoint

Added native offer-creation command using actual shared workOfferInput approval validation and existing manage_contractor_work_offer RPC. Frozen scope/request snapshots, fresh organization/work access and exact active contractor trade coverage precede the write. Strict acknowledgments and exact scoped stored readback confirm immutable contractor/title/scope/trade, separating offered receipt from later state. Focused tests pass for approval, trade/access denial before mutation, retry identity and altered-scope rejection. Native TypeScript/lint and selected-contractor graph export are running. Next: scope-entry form, explicit approval/review/confirmation, same-request uncertain recovery and current-offer/withdrawal management. No production acceptance or assignment completion is claimed.


### Native approved scope form checkpoint

Built native offer form with bounded shared title/scope/reason, approved trade selection, explicit scope-sharing attestation, review and confirmation. Frozen request/scope snapshots and duplicate/stale/completed/unmounted guards preserve uncertain retries, including later known rejection. Focused actual-control tests, native TypeScript and lint pass. The form is not yet connected to selected contractor UI; next integration must keep the selected contractor fixed while confirming/uncertain, then refresh current offer state. Current-offer display/withdrawal remains outstanding. Selected-contractor graph separately passed all-platform Expo export. No live production acceptance is claimed.


### Native work-offer form integration checkpoint

Connected approved offer scope entry to freshly verified contractor selection on triaged work detail. Synchronous parent lock prevents contractor changes, clearing, directory paging/reloading and selected-registration rechecks during pending/uncertain/completed offer requests. The same offer payload/request remains available for retry; parent refresh is explicit. Focused control tests including lock notification, native TypeScript and lint pass. Platform export is running; a final synchronous stale-recheck guard adjustment still requires TypeScript/lint verification. Next: exact current-offer display, withdrawal and retained offer history. Live management/contractor/device acceptance remains open.


### Native current offer checkpoint

Added organization/work-bound pending/accepted offer reader and native detail display. Fresh work and membership are checked before/after with unchanged work revision; bounded immutable shared title/scope/company/trade/status/revision/expiry are projected. Expired pending offers differ from accepted assignments. Approved offer creation is shown only for triaged work without an active offer; the database remains authoritative for conflicts. Focused tests pass; final native TypeScript/lint/export are running. Prior offer form integration passed final TypeScript/lint and all-platform export. Next: manager withdrawal with exact offer scope and retained offer history. Live management/contractor/device acceptance remains open.


### Native manager offer withdrawal command checkpoint

Added manager-only withdrawal helper using actual shared validation and the existing audited offer RPC. Exact offer/work/organization reads and unchanged fresh membership precede/follow mutation; retained terminal records allow safe same-request retry after an earlier withdrawal. Acknowledgments validate exact id/revision and withdrawn-or-expired outcome, with current stored state confirmed separately. Focused tests pass for access/foreign-parent denial, frozen retry, expiry and uncertainty. Native TypeScript/lint are running. Previous current-offer integration passed TypeScript/lint and all-platform export. Next: withdrawal review/confirmation control and retained offer history; live scheduled/progressed-work withdrawal denial, device and cross-account acceptance remain open.


### Native manager withdrawal control checkpoint

Connected withdrawal review/confirmation to nonexpired pending and accepted current offers. A bounded reason, explicit review and confirm precede the existing audited command. Duplicate/stale/completed/unmounted guards retain the exact offer/work/reason/request during uncertain retries, including later rejection. The UI explains that scheduled or progressed work must be resolved before withdrawal; the database remains authoritative. Focused actual-control tests, native TypeScript and lint pass. Three-platform export is running. Next: retained offer lifecycle/audit history, followed by native management visit scheduling and entry/completion review. Live management/contractor/device acceptance remains open.


### Native retained contractor offers checkpoint

Added organization/work-scoped retained offers including declined, withdrawn, expired and completed outcomes. Fresh management/work access precedes/follows count-first deterministic 25-row reads; strict immutable scope/company/trade/state/revision/timestamp projections exclude internal fields. Native detail now shows retained scopes, status, revision and expiry with bounded paging, errors and refresh. Focused tests pass including completed offers and changed-access rejection. Final native TypeScript/lint/export are running. Previous withdrawal control export passed all three platforms. Per-offer decision audit remains next before management scheduling; this register is retained offer history, not the separate actor/reason decision log. Live authenticated/device acceptance remains open.


### Native per-offer decision audit checkpoint

Added exact retained-offer parent verification and organization/offer-scoped decision events with count-first 25-row pages. Fresh unchanged management membership and work access are checked around reads; bounded action/state/revision/reason/time and nullable system actor are validated and projected without internal payload. Retained offer rows now open/close paginated decision history. Focused tests pass; final native TypeScript/lint/export are running. Previous retained-offer export passed all platforms. Next: native management appointment proposal/cancellation, then entry authorization and completion review. Live cross-role/device/concurrency acceptance remains open.


### Native management appointment read checkpoint

Added current proposed/confirmed visit under an exact accepted contractor assignment. Reads bind organization, offer and managed property with validated optional unit, version, eight-hour time bounds and approved shared note. Fresh membership, offer and work revisions are rechecked afterward. Native detail displays current appointment/time/note/reference and controlled absent/error/refresh states, clearly separating confirmation from entry authorization. Focused reader tests pass; final native TypeScript/lint/export are running. Previous per-offer audit passed TypeScript/lint and all-platform export. Proposal/cancellation commands and controls remain next, followed by retained visit history and entry/completion management. Live scheduling/device/concurrency acceptance remains open.

### Native management appointment verification completed

The current appointment reader and management detail display passed focused scope and validation tests, native TypeScript, native lint, and Expo export for web, iOS, and Android. These are build checks; signed-device and live cross-role acceptance remain outstanding. The next implementation step is management appointment proposal and cancellation using the existing `manage_contractor_visit` workflow and shared Jamaica-time validation, followed by retained appointment history and entry/completion management. The production goal remains active.

### Native management appointment command checkpoint

Implemented the shared-validator proposal/cancellation command helper with exact organization, work, assignment, property and unit scope, fresh management authority checks, immutable normalized inputs, retained-state retry support, and separate recorded/current receipts. Focused tests pass for proposal and cancellation replay, scope rejection, known database errors and uncertain acknowledgements. Native TypeScript passes. The helper is not yet connected to user controls; proposal/cancellation review forms and interaction tests are next. Production acceptance remains incomplete.

### Native management appointment cancellation controls

Connected reviewed cancellation controls to the current proposed/confirmed appointment. Frozen action, work, offer, visit, revision, reason and nonce persist across uncertain replies, including later known rejection; stale edits, duplicate submission and post-unmount updates are guarded. Interaction tests, native TypeScript and lint pass. All-platform export started; proposal controls remain next, followed by retained appointment history and entry/completion management. Signed-device and live cross-role acceptance remain outstanding.

### Native management appointment proposal controls

Cancellation all-platform export completed successfully. Added proposal controls for accepted assignments with assigned work and no active appointment, using shared Jamaica-time conversion, explicit note/window approval and review before submission. Interaction tests pass for approval gates, timezone conversion, exact assignment, duplicate/stale protection and frozen retries after uncertainty and later known rejection. Native TypeScript and lint pass. All-platform proposal export started. Retained appointment history and entry/completion management remain next; live and signed-device acceptance remain open.

### Native management retained appointment history

Proposal export passed web/iOS/Android. Retained appointment history is connected to selected work offers, including completed/cancelled/declined visits, count-first 25-row paging, fresh membership and exact retained offer/work/location scope. Focused reader tests, TypeScript and lint pass. History export started. Entry authorization and completion management are next; full production acceptance remains outstanding.

### Native management entry-permit read checkpoint

Retained appointment history export passed all platforms. Implemented the entry-permit history reader with exact retained assignment, work, property/unit, appointment and contractor binding, permitted windows within appointment bounds, fresh membership, 25-row paging and minimal shared fields. Focused tests pass. Native TypeScript and lint started. Reader is not yet displayed; next are permit review UI, authorization/revocation commands and controls, then completion management. Production live acceptance remains open.

### Native management entry-permit display

Connected paged retained entry permits to selected appointments in work-offer history, with loading, error/retry, empty states, permit revisions, instructions and Jamaica-time windows. Historical records are explicitly distinguished from current arrival eligibility. Native TypeScript, lint and focused scope tests pass, including unit mismatch and changed membership revision. All-platform export started. Authorization/revocation controls and completion management remain next; live acceptance is still outstanding.

### Native management entry command checkpoint

Permit display export passed all platforms. Added immutable shared-validator authorization/revocation helper against existing manage_entry_permit RPC, exact work/offer/location/visit/permit checks, fresh management membership, retained-state replay, known-error classification and separate recorded/current receipts. Focused authorization/revocation retry tests, TypeScript and lint pass. Helper is not yet connected to controls; review forms, interaction verification and full scope fixture expansion remain next. Live and device acceptance remain open.

### Native management entry revocation controls

Connected reviewed revocation to authorized permits in retained appointment history, with exact work/offer/visit/permit payload, immutable retry through uncertainty and subsequent known rejection, duplicate/stale guards and unmount protection. Clarifies that revocation does not record departure or cancel appointment. Command fixture tests now include foreign organization/visit, invalid revision and invalid permit state. Focused command/control tests, TypeScript and lint pass. Export started. Entry authorization form and completion management remain next; full live/device acceptance remains incomplete.

### Native management entry authorization controls

Revocation export passed all platforms. Connected reviewed entry authorization to confirmed/scheduled appointments, with displayed appointment bounds, Jamaica-time inputs, explicit sharing approval and authority reason. Interaction tests pass for review/approval gates, timezone conversion, exact assignment, duplicate/stale guards and frozen retries. Initial TypeScript/lint passed; final checks after bounds display and all-platform export started. Server enforces appointment bounds/current scheduling and unique active authorization. Completion management and live/device acceptance remain open.

### Native management completion-report read checkpoint

Entry authorization final TypeScript, lint and all-platform export passed. Implemented the management completion reader for exact retained offer/work/organization scope, fresh membership, immutable report/review fields, state validation and count-first 25-row paging. Focused tests pass for scope, invalid records, duplicate records, empty/error states and revoked work access. Native TypeScript and lint started. Completion display, supporting evidence review and approve/request-changes controls remain next. Production live and signed-device acceptance remain outstanding.

### Native management completion-report display

Connected paged completion reports to selected work-offer review with contractor summary, tests, outstanding items and stored management response. Distinguishes submission from completed work. Reader/display tests, TypeScript and lint pass, including loading/error/empty/paging/refresh. All-platform export started. Supporting evidence review and approve/request-changes commands/controls remain next, followed by return-visit management and production acceptance.

### Native management report-linked evidence reader

Completion display all-platform export passed. Added report-linked evidence reader with exact report/work/offer/organization/contractor scope, uploaded-only minimal metadata, filename/MIME/size checks, bounded paging and fresh membership/report access checks. Focused tests, TypeScript and lint pass. Evidence display and authenticated private-file opening remain next, followed by completion decision controls and return visits. Production acceptance remains outstanding.

### Native management report evidence metadata display

Connected selectable report-linked evidence metadata to completion report review, with minimal names/types/sizes, bounded paging, refresh and loading/error/empty states. Reader/display and completion display tests, TypeScript and lint pass. Existing display harness was updated for the new child and selection state. All-platform export started. Private authenticated file opening remains next, then approve/request-changes decisions and return visits. Live/device production acceptance remains open.

### Native management private evidence signing

Evidence metadata display all-platform export passed. Added management private-file signing helper with exact report/work/organization/offer/contractor/link checks before and after signing, fresh membership/work access, two-minute signed URL and exact Supabase host/bucket/path validation. Focused tests pass for authorized access, foreign/revoked records and malformed links. TypeScript/lint checked. File-opening UI and interaction verification remain next, followed by completion decisions and return visits. Live storage/device acceptance remains outstanding.

### Native management report evidence file opening

Connected authenticated private-file opening to report-linked evidence metadata. Interaction tests pass for exact work/offer/report/file arguments, duplicate taps, fresh links per retry, failure recovery and unmount handoff suppression. Evidence display tests and native lint pass; TypeScript and all-platform export checked separately. Completion review decisions and return visits remain next; live Storage, browser/device and production acceptance remain open.

### Native management completion review command

Private evidence opening all-platform export passed. Added frozen shared-validator approve/request-changes command using existing manage_completion_report RPC, exact work/offer/report scope and fresh membership, retained-state retry, acknowledgement validation and separate recorded/current receipts. Focused tests, native TypeScript and lint pass. Approval requires explicit evidence-reviewed confirmation; review messages cannot rewrite contractor submissions. Reviewed decision forms/interaction tests, retained decision audit and return visits remain next. Live multi-role and signed-device production acceptance remain outstanding.

### Native management completion decision controls

Connected reviewed approve/request-changes forms to submitted reports with shared contractor review, decision reason, explicit evidence confirmation for approval, immutable uncertain retry and duplicate/unmount guards. Command, interaction and completion display tests, TypeScript and lint pass. All-platform export started. Retained completion decision audit and return-visit management are next. Live multi-role, storage and signed-device acceptance remain open; the full production goal remains active.

### Native management completion decision audit

Completion review controls export passed all platforms. Added exact report/work/offer/organization audit with fresh membership and retained-parent checks, approved action/state validation, minimal actor/reason/revision/time fields and count-first 25-row paging; connected to selected report review beside linked evidence. Audit and completion display tests pass. Native TypeScript/lint checked; audit all-platform export started. Return-visit management remains next. Full live multi-role/device and production acceptance remain incomplete.

### Native management return-visit command

Completion audit export passed all platforms. Added exact work/offer/report correction-context reader and frozen shared-validator return-visit command using existing request_contractor_return_visit RPC. Preserves report/offer/work revisions and nonce across retry, verifies recorded assigned-work acknowledgement separately from current state, and refreshes management membership. Focused tests, TypeScript and lint pass. Reviewed return controls and interaction tests remain next, followed by broader native management/production verification. Live cross-role/device acceptance remains incomplete.

### Native management reviewed return-visit controls

Connected fresh correction-context reader and reviewed return request to changes-requested reports, with accepted/in-progress display eligibility, explicit approval, immutable report/offer/work revisions, duplicate protection and frozen uncertain replay. Interaction/display tests, native TypeScript and lint pass. All-platform export started. Next: broader native regression and remaining management/reporting/finance journeys; live role, Storage, signed-device and deployment acceptance remain outstanding. The full production plan remains active.

### Native management workflow regression and reporting start

The full test:native-applications command completed with exit zero and 91 PASS checkpoints, covering current native prospect/application/contractor/security/owner/management readers and controls. Return-visit export passed web/iOS/Android. These fixture/build checks do not replace live cross-role/device acceptance. Started the maintenance-report helper using the existing reportPeriod validator and organization-scoped independent state/open-priority counts, preserving unavailable values rather than zero. Reporting helper tests, display and native bundler support are next; it is not connected yet. Production goal remains active.

### Native maintenance reporting helper verification

Maintenance cohort helper focused tests pass for shared Jamaica-date validation and inclusive end-day boundary, exact organization scope, all nine states, open-priority exclusion of completed/closed/cancelled, zero versus unavailable counts and changed membership. Added shared pure reports folder to Metro watch roots. Native TypeScript/lint checked. Date-filtered reporting screen and display/interaction/export verification remain next; reporting is not yet exposed in the app. Full production and live acceptance remain outstanding.

### Native maintenance workload screen

Connected management maintenance report from account home and registered native route, with validated Jamaica date filters/all-date reset, current-state and open-priority counts, explicit independent-read/cohort semantics, unavailable alerts and queue links that disclose their all-date scope. Helper/display tests, native TypeScript and lint pass. All-platform export started. Further native management/finance/reporting, live acceptance and production deployment remain incomplete.

### Native contractor coordination reporting

Maintenance report export passed all platforms. Added contractor coordination report with all retained offer/appointment states including completed, completion-report outcomes, Jamaica creation-date filters, independent scoped counts and zero/unavailable distinction. Connected screen/navigation and clear record-count versus performance/attendance semantics. Helper/display tests pass; final TypeScript/lint checked and all-platform export started. Further management/preventive/finance workflows and live role/device/deployment acceptance remain open.

### Native preventive-plan register reader

Contractor coordination export passed all platforms. Added preventive-plan register reader with exact management organization/state, count-first 25-row paging, valid calendar/cadence/revision checks, minimal summary fields and fresh membership. Focused tests, native TypeScript and lint pass. Register display, plan detail, occurrences/history and approved plan/issue/skip controls remain next. The rejected preventive outbox bridge remains unapplied; independent native read work does not alter that proposal. Live/device and production acceptance remain outstanding.

### Native preventive-plan register display

Connected preventive register from account home with active/paused/retired state switching, first-page reset, due-date/cadence/revision summaries, bounded FlatList, paging/refresh and loading/error/empty states. Focused display tests, TypeScript and lint pass. All-platform export started. Plan detail, occurrence/decision history and approved actions remain next. Register does not yet provide plan mutation controls. Full production and live/device acceptance remain incomplete.

### Native preventive-plan exact detail reader

Preventive register export passed all platforms. Added exact plan detail with organization/property/unit binding, minimal property name and shared plan description/priority/cadence/due date/revision, fresh management membership and missing-record handling. Scope/calendar/cadence/revision tests, native TypeScript and lint pass. Detail display/navigation and occurrence/decision history remain next, then approved plan actions. Production and live/device acceptance remain outstanding.

### Native preventive-plan detail display

Connected exact preventive-plan detail from the register, displaying shared scope, managed property/unit, priority, cadence, due date and revision with refresh and missing/error/loading states. Focused detail and register display tests, native TypeScript and lint pass. All-platform export completed successfully for web, iOS and Android. Occurrence/decision history and approved preventive actions remain next; live role/device and production acceptance remain outstanding.

### Native preventive management decision history

Added exact organization/plan-scoped retained decision history with fresh management membership, count-first 25-row paging, actor/reason/revision/time and generated-work navigation. Skip decisions distinguish skipped maintenance from completion. Helper/display and existing detail display tests pass; native TypeScript and lint pass. All-platform export completed successfully for web, iOS and Android. Approved before/after scope snapshots, occurrence and skipped-date registers, and preventive action controls remain next. Production and live/device acceptance remain outstanding.

### Native preventive approved scope snapshots

Decision history now projects and displays approved before/after scope, property/unit references, priority/state, due date and cadence. Reader validates plan/organization bindings, revision sequence, immutable property/unit, and issue/skip scope and cadence advance. Raw payloads and unrelated stored fields are excluded. Focused reader/display/detail tests pass; final native TypeScript/lint and web/iOS/Android export pass. Occurrence/skipped-date registers and action controls remain next. Production and live/device acceptance remain incomplete.

### Native issued preventive occurrences

Connected retained issued-occurrence register to native plan detail with count-first 25-row paging, approved occurrence scope/date, decision reference and generated work-order navigation. Reader validates exact organization/plan, active retained scope and matching due date, unique date/event/work references and fresh membership. Reader/display/detail tests pass. Native TypeScript, lint and web/iOS/Android export pass. Skipped-date register and preventive action controls remain next; production and live/device acceptance remain outstanding.

### Native skipped preventive-date register

Connected retained skipped-date register to native plan detail with approved scope/date, approval actor/reason, decision reference and 25-row paging. Exact plan/organization/event/action/revision and null work-order bindings are validated with fresh membership and unique dates/events. Reader/display/detail tests pass. Final native TypeScript/lint and web/iOS/Android export pass. Full native regression completed with exit zero and 105 PASS checkpoints. These checks do not replace live role/device acceptance. Preventive action controls are next; live/device and production acceptance remain incomplete.

### Native preventive issue/skip command verification

Added frozen scheduled-decision helper using the actual shared preventive approval validator and existing manage_preventive_plan/skip_preventive_occurrence RPCs. Exact acknowledgement, organization/plan/actor/request-bound retained decision, reason, before/after revisions and immutable scope/cadence are verified, with fresh management membership and advanced-revision replay. Focused tests cover approval, known versus uncertain rejection, foreign/mismatched receipts, schedule mismatch and changed authority. Native TypeScript/lint checked. Helper is not yet connected to UI; reviewed issue/skip controls remain next, then plan authoring/revision. No database/outbox changes were made. Production/live/device acceptance remain incomplete.

### Native reviewed preventive scheduled decisions

Connected issue/skip controls for active due plans with explicit approval, validated reason, reviewed scheduled date/cadence advance, backlog disclosure and outcome references. Review uses a synchronous edit lock; duplicate and stale callbacks, uncertain frozen retries, later known rejection and unmount guards are tested. The display clock is captured in state while authoritative due eligibility remains server checked. Focused command/control/detail tests pass. Final native TypeScript/lint and web/iOS/Android export pass. Plan create/revise controls remain next; live/device and production acceptance remain incomplete.

### Native preventive approved revision helper

Added frozen plan-revision helper using the actual shared preventive validator and existing manage_preventive_plan RPC. It verifies exact recorded actor/request/organization/plan/reason, revision sequence, unchanged property/unit and all approved title/description/priority/cadence/date/state fields before success. Retained advanced-revision replay and known versus uncertain failures are tested, alongside invalid date/cadence/approval and mismatched scope receipts. Focused tests, native TypeScript and lint pass. The helper is not yet exposed in UI; revision form including pause/permanent retirement, then approved managed-location creation, remain next. Production/live/device acceptance remain incomplete.

### Native reviewed preventive revision form

Connected preventive revision form to plan detail with scope/title/priority, fixed-day cadence, Jamaica due date, active/paused/permanently retired state, explicit approval and validated review. Retained history and missed-maintenance semantics are disclosed. Synchronous review lock, duplicate/stale guards, frozen uncertain retry after later known rejection and unmount suppression are tested. Focused control/detail tests, native TypeScript, lint and web/iOS/Android export pass. Approved managed-location creation remains next. Production/live/device acceptance remain incomplete.

### Native managed-location readers

Added organization-scoped managed property register and exact property/unit selection, with minimal names/references, count-first 25-row paging and fresh membership. Unit register verifies the managed parent before/after loading and rejects foreign/duplicate/invalid records. Focused scope/paging/redaction/membership tests pass. Final native TypeScript and lint pass. These readers are not yet exposed in UI. Managed-location selection and reviewed plan creation remain next; production/live/device acceptance remain incomplete.

### Native preventive creation command

Added frozen plan-creation helper using actual shared approval/scope/date validation, exact managed property/unit access and existing manage_preventive_plan RPC. It verifies returned UUID, initial revision, null prior scope/work order, actor/request/organization-bound retained decision and every approved scope/location field, with fresh membership and advanced-current-plan replay. Focused tests cover invalid new-plan state/revision, foreign selected property, malformed receipt, nonnull prior scope and known/uncertain outcomes. Native TypeScript and lint pass. The helper is not yet exposed in UI; property/unit selection and reviewed creation form remain next. Production/live/device acceptance remain incomplete.

### Preventive write authority recheck

Review of creation/location sequencing found a client-side authority gap. Creation, revision and issue/skip commands now compare organization/role/membership revision again after target validation and before RPC. Focused tests prove changed pre-write authority sends no RPC, while post-write authority changes remain uncertain and preserve request recovery. All three command tests, native TypeScript, lint and web/iOS/Android export pass. Managed-location picker and creation UI remain next; live/device and production acceptance remain incomplete.

### Native managed-property picker component

Added bounded managed-property picker with scoped selection recheck, duplicate selection lock, disabled paging during selection, unavailable/empty/loading feedback and unmount handoff suppression. Actual component interaction tests cover paging, fresh selected location, duplicate callbacks, revoked selection and unmount. Focused tests, native TypeScript and lint pass. This component is not yet exposed through app navigation; unit/property-wide choice, reviewed creation form and route wiring remain next. Production/live/device acceptance remain incomplete.

### Native property-wide/unit picker component

Added exact selected-property unit picker with 25-row paging and explicit property-wide/common-area choice, including zero-unit properties. Selection rechecks exact property/unit access; duplicate selection and paging while pending are guarded, with revoked selection feedback and unmount handoff suppression. Actual component tests cover both selected unit and null-unit scope, paging/empty/error/loading and duplicate/unmount behavior. Native TypeScript/lint pass. Pickers are not yet exposed through navigation; reviewed creation form and route wiring remain next. Production/live/device acceptance remain incomplete.

### Native reviewed preventive creation form component

Added reviewed creation form bound to selected property/unit, with title/scope/priority, fixed interval/date, active/paused state, explicit approval and created-plan navigation. Synchronous review/edit lock and frozen uncertain retry persist through later known rejection; duplicate/stale callbacks and unmount suppression are tested. Focused component tests, native TypeScript and lint pass. Form/pickers are not yet connected through app routes. Route orchestration and navigation/export verification remain next, followed by broader management/finance and live/device acceptance. Production goal remains active.

### Native preventive creation journey connected

Connected create-plan route from preventive register and native stack. Verified-account journey selects exact managed property, then unit/property-wide scope, then reviewed approved creation. Synchronous phase guards reject foreign/stale/duplicate handoffs; changing property resets selection before drafting. Creation retains uncertain request in the form and links confirmed created plan. Route/register tests, native TypeScript/lint and web/iOS/Android export pass. Full native regression completed with exit zero and 115 PASS checkpoints. These checks do not replace live authenticated/device acceptance. Live role/device/database acceptance, remaining management/finance and production launch remain incomplete.

### Native management presence history reader

Added retained work-order presence reader with exact organization/property, nested visit/offer/work bindings, exact unit, arrival/departure state/time validation and count-first 25-row paging. Minimal presence/visit/permit references exclude private unrelated fields. Fresh membership and work location are checked before returning. Focused tests cover foreign work/location, invalid chronological/state records, duplicate rows, changed authority and empty results; native TypeScript/lint pass. Reader is not yet connected to UI; presence display and per-record security decision audit remain next. Further native management/finance and live/device/production acceptance remain incomplete.

### Native management presence history display

Connected retained arrival/departure history to native management work detail, with Jamaica timestamps, presence/visit/permit references, state/revision, 25-row paging and refresh/loading/error/empty feedback. Display distinguishes recorded presence from work completion or current entry authority. Focused component tests, native TypeScript, lint and web/iOS/Android export pass. Per-record security decision audit remains next, followed by further management/finance and live/device/production acceptance.

### Native management security decision audit

Added exact presence reader and selected-presence decision audit, scoped to organization/work/visit/property/unit and presence references. Audit validates actor/reason, check-in/check-out previous/new-state mapping, revision/time and fresh membership/parent access; raw request payloads remain excluded. Presence rows now open/close paged security decisions with Jamaica timestamps. Focused parent/audit/display/selection tests, native TypeScript, lint and web/iOS/Android export pass. Property security administration and remaining native management/finance remain next; live role/device and production acceptance remain incomplete.

### Native property security assignment register reader

Added exact organization/managed-property security assignment reader, retaining active/inactive records with minimal account reference, state/revision/time and count-first 25-row paging. Property access and fresh management membership are checked; malformed/foreign/duplicate assignments are rejected. Focused scope/state/paging/redaction/membership tests, native TypeScript and lint pass. Reader is not yet exposed in UI; register/detail/audit and reviewed account approval/revocation remain next. Further native management/finance and live/device/production acceptance remain incomplete.

### Native security assignment detail and approval history

Added exact organization-scoped security assignment detail with verified managed-property access and retained active/inactive state. Added count-first 25-row approval history with actor/reason, previous/new active state, revision/time and exact parent scope. Fresh membership and immutable assignment account/property bindings are rechecked; raw request payloads remain excluded. Focused detail/history tests, native TypeScript and lint pass. Readers are not yet exposed in UI; property selection/register/detail/audit screens and reviewed approval/revocation controls remain next. Production/live/device acceptance remain incomplete.

### Native security assignment detail/history display

Added native exact assignment detail route with verified identity, property/account references, active/inactive revision and approval-access semantics. Connected paged approval history with actor/reason, previous/new active state and Jamaica time. Focused detail/history display tests, native TypeScript, lint and web/iOS/Android export pass. The property register/navigation and reviewed approval/revocation controls remain next; detail route is not yet reachable from a register. Production/live/device acceptance remain incomplete.

### Native property security register/navigation connected

Connected account-home property security route, verified managed-property picker, active/inactive assignment register and exact assignment detail/history navigation. Register has 25-row paging, minimal account references, managed property name and loading/error/empty/refresh feedback. Route selection guards prevent unit/duplicate handoffs and allow property reset. Focused route/register/detail tests, native TypeScript, lint and web/iOS/Android export pass. Reviewed security assignment creation/activation/revocation controls remain next. Production/live/device acceptance remain incomplete.

### Native security assignment activation/revocation command

Added frozen existing-assignment command using actual security approval validator and author_property_security_assignment RPC. Pre-write membership and exact target are checked; retained actor/request/organization/assignment decision, active state/reason/revision and immutable property/account are verified before success. Tests cover activate/revoke, validation, advanced replay, mismatched receipts and pre/post-write authority changes with known versus uncertain results. Native TypeScript/lint pass. Helper is not yet exposed in UI; reviewed controls and new verified-email assignment creation remain next. Production/live/device acceptance remain incomplete.


### Native security assignment activation/revocation controls

Assignment details now expose reviewed activation/revocation with explicit approval and reason, immutable property/account scope, duplicate guards and frozen uncertain-response retries. Focused actual-component and command checks pass. Native build verification remains in progress; live account/device acceptance remains open. Next: verified-email assignment creation and remaining management inventory/finance/access administration.


Native security decision checkpoint: focused command/detail/control checks, TypeScript, lint and web/iOS/Android export passed. New security assignment creation command is implemented with the shared validator, property-bound verified-email RPC, retained creation receipt, fresh management checks and frozen replay; focused command checks pass. Creation form/navigation and live account/device acceptance remain outstanding.


### Native verified-account security assignment creation

Connected security assignment creation to the selected managed-property register. The form requires a verified account email, reason and explicit approval, shows a normalized review, retains the exact request across uncertain responses, prevents duplicate/stale/unmounted writes, and links to the exact assignment only after a verified receipt. Focused command/form/register tests, native TypeScript, lint and web/iOS/Android export passed. Broad native regression is running. Live verified-account/device acceptance and remaining native inventory/finance/access administration remain open.

Native security creation regression checkpoint: the complete registered native suite exited successfully with 131 passing checkpoints. Web/iOS/Android export also exited successfully. Next implementation cycle: private managed-property/unit inventory journeys; finance, owner access and staff administration remain in the original scope. Production acceptance remains unproven until live-role/device/provider and release gates pass.


### Native private property/unit inventory reader

Added exact organization-scoped private property details and count-first 25-row property-bound unit inventory. Validates private name/area/address, dimensional bounds, revisions, unique units and organization-bound held/converted tenancy protections; rechecks membership and property revision after reads. Focused reader tests and native TypeScript pass. Reader UI and reviewed inventory authoring remain next; broader native finance/access and all live/device/provider production gates remain in scope.


### Native private inventory screen connected

Connected account-home private inventory navigation, verified managed-property picker and bounded unit register. Screen shows private property address/area/revision, unit dimensions with explicit missing values, held/occupied tenancy protection, refresh/paging and unavailable/empty states. Focused route/display tests, native TypeScript and lint passed. Web/iOS/Android export is running; reviewed inventory creation/revision and retained audit remain next. All remaining native finance/access administration and live/device/provider production gates remain open.


### Native inventory retained history reader

Private inventory screen web/iOS/Android export completed successfully. Added count-first 25-row retained inventory history scoped to exact organization/property, validating actor/time, action-specific targets and revisions, property fields, unit dimensions and listing linkage. Output excludes request identity and extra payload fields; fresh membership and exact property access are rechecked. Focused history tests and native TypeScript pass. History display, reviewed property/unit creation/editing and remaining native finance/access administration remain next. Live/device/provider/release acceptance remains incomplete.


### Native inventory history display connected

Connected paged retained inventory history to the private property/unit register. Displays action, recorded actor, revision, whitelisted retained fields, event reference and Jamaica timestamps; handles missing field values, empty/error/loading, paging and refresh. Focused history/register display checks pass. Native type/lint and web/iOS/Android export are being verified. Reviewed inventory authoring and remaining native finance/access administration remain next; live/device/provider/release acceptance remains incomplete.

Inventory history verification checkpoint: native TypeScript and lint exited successfully. Web bundle compiled; iOS/Android export remains running on the same tracked session. No deployment or live inventory mutation was performed.


### Native inventory authoring commands

Inventory history screen web/iOS/Android export passed. Added frozen reviewed property/unit create/update commands using the shared inventory validator and author_managed_inventory RPC. Requires explicit local approval, fixed property/target binding, fresh management membership, minimal exact unit reads and retained organization/actor/request/action/target/revision/payload/result receipt before success; handles known rejections, uncertain responses and later revisions. Focused command checks pass. First native TypeScript process crashed with exit 139 and is being rerun; forms/navigation and live/device acceptance remain outstanding. No live inventory record changed.

Inventory command verification checkpoint: the fresh native TypeScript run exited successfully; lint and focused authoring command checks also passed. Commands remain unexposed until reviewed forms are connected.


### Native reviewed inventory authoring form

Added reusable property/unit editor with required field/dimension parsing, explicit unchecked approval, normalized review, frozen request, stale/duplicate/unmounted guards and sticky uncertainty through later rejection. Shows retained/current revision receipt and refresh after confirmed success. Actual-component interaction tests and native TypeScript pass. Form is not yet connected to register/navigation; next cycle must preserve pending editor outside virtualized rows, connect create/update actions with property/target/revision bindings, and suppress protected-unit edits. Production acceptance remains open.


### Native inventory register authoring connected

Connected reviewed property updates, managed-unit creation and unprotected-unit updates. Fixed editor property/target/revision and canonical initial fields come from the scoped register; protected units have no edit action. A synchronous selection guard opens the editor outside virtualized rows and confirmed refresh returns to reloaded inventory. Focused register handoff/protected-unit checks and lint pass; native TypeScript and web/iOS/Android export are running. Property creation navigation, deeper editor numeric-field interactions and live/device acceptance remain next. Remaining finance/access/provider/release scope stays open.


### Native managed-property creation entry

Previous property/unit editor web/iOS/Android export passed. Connected creation before existing-property selection with null target/property and revision zero, identity-scoped editor, stale picker guard and confirmed return to refreshed picker. Extended editor checks for rejecting exponent syntax and converting half-step dimensions, negative floor and blank optional size to canonical numeric/null fields. Focused route/editor checks, native TypeScript and lint pass. Updated platform export is running. Live-role/device acceptance and remaining finance/access administration/provider/release gates remain open.


### Native administrator owner-access register reader

Inventory creation/editor platform export passed. Added administrator-only count-first 25-row owner access register bound to exact organization/managed property, retaining active/revoked account references and validated revisions/timestamps. Fresh membership/property checks reject malformed/foreign/duplicate records and manager access. Focused reader, native TypeScript and lint pass. Register/detail/approval-history UI and reviewed approval/revocation remain next. Broad native regression stopped on a transient TypeScript package load syntax error; subsequent package load passed and a fresh regression is running. Live/device/provider/release acceptance remains open.


### Native owner-access exact detail and retained approval history

Added administrator-only exact owner-access detail and count-first 25-row history bound to organization/access and managed-property/account identity. Validates retained active/revoked states, actor/reason/revisions/time and creation versus later transitions; excludes request payload. Fresh membership and parent bindings are rechecked. Focused detail/history checks, manager denial, native TypeScript and lint pass. Readers are not yet exposed; register/detail/history UI and reviewed approval/revocation remain next. Broad native inventory regression rerun is still tracked; live/device/provider/release acceptance remains open.

Native inventory regression rerun exited successfully with 139 passing checkpoints, including connected inventory creation/editor/history and administrator owner-access register. Newly added owner detail/history have separate focused checks; a broader suite including those remains for a later integration checkpoint.


### Native owner-access register/detail/history connected

Connected account-home owner access administration, managed-property selection, administrator-scoped active/revoked register, exact detail navigation and paged approval history. Displays account/property references, current permission revision, actor/reason, retained transitions and Jamaica time with explicit portfolio-permission versus legal-title semantics. Focused route/register/detail/history UI checks, native TypeScript and lint passed. Platform export is running. Reviewed owner access creation/activation/revocation controls and live administrator/device acceptance remain next; full finance/access/provider/release scope remains open.


### Native reviewed owner-access activation/revocation

Owner-access display export passed on all platforms. Added administrator-only existing-access command using shared ownerAccessInput and author_owner_property_access RPC; verifies frozen request, immutable property/account, retained actor/request/action active-state/reason/revision and current advanced replay before success. Connected explicit approval/reason/review controls with duplicate/stale/unmount guards and sticky uncertain retries. Focused command/control/detail checks pass, including manager denial. New verified-email owner access creation remains next. Current TypeScript/lint/export checks are tracked; live/device/provider/release acceptance remains open.


### Native verified-email owner-access creation command

Reviewed existing-access decision export completed successfully on web/iOS/Android. Added administrator-only frozen creation command using shared ownerAccessInput, exact managed property, normalized verified-account email and author_owner_property_access RPC. Success requires retained organization/actor/request/access/state/reason/revision creation receipt, current property-bound access and fresh administrator membership; unknown responses retain uncertainty. Focused creation checks including manager denial, native TypeScript and lint pass. Command is not yet exposed; reviewed creation form/register handoff is next. Production/live/device/provider/release gates remain open.


### Native owner-access creation connected

Connected administrator-reviewed verified-email access creation to the exact managed-property register. Selected form lives outside virtualized rows, requires explicit approval/reason, reviews canonical email/property, freezes uncertain requests, and exposes exact detail navigation only after confirmed retained receipt. Copy distinguishes portfolio reporting permission from legal title/shares and account creation. Focused creation/register handoff checks, native TypeScript and lint pass. Platform export is running. Broader native regression and live administrator/device acceptance remain open; staff administration, finance and provider/release gates remain in scope.


### Native administrator staff directory reader

Owner-access creation web/iOS/Android export completed successfully. Added fresh administrator-only staff_membership_directory RPC reader with 25-row page/total validation, unique account references, approved staff roles, email verification and UUID membership revisions. Output excludes extra record fields; changed administrator membership rejects results. Focused reader tests pass; native TypeScript/lint tracked. Reader screen, membership change history and reviewed assign/change/revoke controls remain next. Staff invitations, native finance and live/device/provider/release acceptance remain open.


### Native retained staff membership history reader

Added administrator-only organization-scoped count-first 25-row staff membership history. Validates immutable actor/account/email snapshot, approved previous/new roles and nullable revisions consistent with database create/revoke behavior, reason/time and unique events. Excludes request identity and rechecks administrator membership after reading. Focused history checks and lint pass; native TypeScript is tracked. Directory/history UI and reviewed staff assign/change/revoke controls remain next; invitations/native finance and live/device/provider/release acceptance remain open.


### Native staff directory/history screens connected

Connected account-home staff administration, paged administrator directory and retained membership history route. Directory shows approved role, email verification, immutable account and membership revision with keep-another-admin/access-limit semantics. History shows email snapshot, previous/new role, actor/reason/account/event and Jamaica time with bootstrap-history caveat. Focused display/refresh/paging/loading/error/empty tests, native TypeScript and lint pass. Platform export is running. Reviewed staff assign/change/revoke, invitations, native finance and live/device/provider/release acceptance remain open.


### Native reviewed staff membership command

Added administrator-only frozen staff assignment/change/revocation command with actual membershipInput and manage_staff_membership RPC. Validates approved email/reason/role/revision and exact retained organization/actor/request/target/email/previous/new revision/role receipt. Fresh administrator checks distinguish self-admin revision refresh from other membership changes; self-authority loss remains uncertain and requires another administrator to inspect history. Focused command checks, native TypeScript and lint pass. Helper is not yet exposed; reviewed role-selection forms and exact directory handoff remain next. Staff display export crashed with exit 139; tracked fresh export has compiled web/iOS and Android is pending. Invitations/native finance and live/device/provider/release acceptance remain open.


### Native staff reviewed role form connected

Connected new verified-account assignment and exact member role/revocation editing outside virtualized rows. Form requires explicit approval/reason/review, fixes current email/revision, preserves uncertain requests through later rejection and prevents duplicate/stale/unmounted actions. Verified receipt shows retained role/revision; self-authority uncertainty instructs another administrator history review. Focused form and new/existing directory handoff tests pass; native TypeScript/lint/export tracked. Staff invitations/native finance and live administrator/device/provider/release acceptance remain open.


### Native administrator invitation register reader

Reviewed staff editor export completed successfully on web/iOS/Android. Added organization-scoped administrator-only count-first 25-row staff invitation reader preserving pending/accepted/declined/revoked/expired states, approved role/email, current revision and created/expiry timestamps. Rejects foreign/malformed/duplicate records and changed administrator membership; excludes extra private fields. Focused reader checks pass; native TypeScript/lint tracked. Register/detail/history UI, reviewed create/resend/revoke and recipient acceptance remain next. Invitation delivery configuration, finance and live/device/provider/release gates remain open.


### Native exact administrator invitation detail

Extracted shared invitation record validation and added exact administrator detail bound to organization/id with minimal fields, safe missing record and fresh membership check. Focused register/detail checks pass. TypeScript exposed missing unknown-field narrowing in the shared helper; narrowing fixed and rerun tracked. Database supports create/accept/decline/revoke and retained expiry, without resend approval action; delivery retry must stay separate. Detail/history UI and reviewed create/revoke/recipient decisions remain next. Finance/provider/device/release acceptance remains open.


### Native exact invitation retained history

Invitation shared-record/detail TypeScript rerun passed. Added administrator-only exact invitation history scoped to organization/invitation and fresh parent email/role binding, with count-first 25-row paging and actor/reason/revision/Jamaica-ready timestamps. Validates create→pending revision one and pending→accepted/declined/revoked/expired later revisions; raw request payload omitted. Focused all-transition/scope/manager-denial/history tests and lint pass; TypeScript tracked. Register/detail/history screens and create/revoke/recipient decisions remain next. Finance/provider/device/release acceptance remains open.


### Native invitation register/detail/history screens

Connected staff administration invitation navigation, bounded register, exact detail and retained approval/recipient history. Displays current approved email/role/state/revision, expiry and Jamaica time, action/state transition actor/reason/history. Explicit copy separates invitation state from provider delivery and requires exact verified email/current approval before access. Focused register/detail/history states/navigation/paging/refresh tests, native TypeScript and lint pass. Platform export is running. Reviewed create/revoke and recipient acceptance remain next; native finance and live/device/provider/release acceptance remain open.


### Native administrator invitation creation/revocation commands

Invitation register/detail/history web/iOS/Android export passed. Added frozen administrator create/revoke command using shared invitationInput and manage_staff_invitation RPC, fresh membership and exact revoke parent. Requires retained organization/invitation/actor/request/action/transition/reason/version/canonical payload receipt plus immutable email/role and current record before success. Focused create/revoke validation, advanced replay, wrong receipts, manager denial and authority uncertainty tests, native TypeScript and lint pass. Commands are not yet exposed; reviewed creation/revocation forms and recipient acceptance remain next. Delivery outcomes/provider setup, native finance and live/device/release acceptance remain open.


### Native administrator invitation reviewed forms connected

Connected reviewed invitation creation outside virtualized register rows and exact pending-invitation revocation in detail. Requires explicit approval/reason/review, preserves frozen unknown requests through later rejection, blocks duplicate/stale/unmounted actions, hides closed-invitation controls and links to verified recorded details. Copy distinguishes receipt from email delivery. Focused create/revoke/closed-state/control and register/detail handoff checks pass; current native TypeScript/lint/export tracked. Recipient invitation discovery/acceptance remains next; delivery/provider configuration, native finance and live/device/release acceptance remain open.


### Native verified recipient invitation readers

Administrator invitation forms export passed on web/iOS/Android. Added fresh verified identity/email-bound 25-row recipient invitation register and exact staff_invitation_summary RPC reader with organization/approved role/state/revision/expiry/available decisions and blocked reason. Rechecks identity/email after reads and rejects foreign/malformed/unverified/anonymous/account-change results; excludes administrator history/extra fields. Focused recipient read checks, native TypeScript and lint pass. Recipient discovery/detail UI, explicit consent accept/decline and deep-link handoff remain next. Native finance/provider/device/release acceptance remains open.


### Native recipient invitation discovery/detail screens

Connected account-home recipient invitation discovery, bounded current-email register and exact organization/role/email/state/revision/expiry/decision-availability summary. Detail explains approved organization access and shows blocked reason, safe missing/error/loading/refresh. Focused display/navigation checks pass. TypeScript identified copied per-row email field absent from narrow reader; replaced title with approved role and removed unused import, reruns/export tracked. Explicit-consent accept/decline commands/controls and email deep-link native handoff remain next. Finance/provider/device/release acceptance remains open.


### Native recipient invitation consent commands

Recipient discovery/detail TypeScript and web/iOS/Android export passed. Added frozen accept/decline commands using actual invitationInput, reviewed organization/role/email context, fresh verified identity and exact invitation summary. manage_staff_invitation acknowledgement is checked against recipient-visible email/role/state/revision/accepted-account/response timestamp and fresh summary/identity; internal administrator audit remains private. Focused consent/decision/receipt/identity tests, native TypeScript and lint pass. Commands are not yet exposed; explicit-consent form and native email-link handoff remain next. Finance/provider/device/release acceptance remains open.


### Native recipient invitation explicit consent controls

Connected available accept/decline choices to exact recipient invitation detail with fixed organization/role/email/revision, reason visible-to-admin disclosure, unchecked explicit consent and canonical review. Preserves exact unknown requests through later rejection, blocks duplicate/stale/unmounted writes, hides unavailable choices and refreshes only after verified response. Focused consent/detail checks, native TypeScript and lint pass. Platform export is running. Native email-link handoff, broader regression/live recipient/admin/device acceptance remain next; finance/provider/release gates stay open.


### Native invitation link routing

Recipient consent export completed successfully for web, iOS and Android. Added Expo native-intent invitation handoff from exact /account/invitations/UUID paths and the configured app scheme to /team-invitation?id=UUID. HTTPS rewrites require the explicitly configured canonical EXPO_PUBLIC_APP_URL origin; foreign/malformed/query/fragment invitation links are unchanged, as are authentication callbacks. Actual helper/wrapper tests, native TypeScript and lint pass. Link export completed successfully for web, iOS and Android. Universal-link domain association and device launch still require approved app/domain configuration; sign-in return-to-invitation handoff, broad regression, native finance and live/provider/release acceptance remain open.


### Native invitation sign-in handoff

Unsigned valid invitation detail now passes only its exact UUID to sign-in. Sign-in validates a single identifier, freezes it before authentication, verifies the current signed-in account and returns to that invitation; malformed, duplicate and arbitrary redirect inputs fall back to account home. Recipient detail still verifies exact invited email through its reader/RLS. Extended actual screen/control tests cover unsigned navigation, bad identifiers, changed actor, async parameter changes, duplicate submissions and unmount suppression. TypeScript/lint and web/iOS/Android export passed. Broad native regression completed successfully (169 PASS checkpoints). New-account confirmation/recovery return continuity, universal-link associations/device tests, native finance, live providers and release acceptance remain open.


### Native finance membership and approved account reader

Added dedicated financeAccess using fresh verified nonanonymous identity and exact staff membership/revision, allowing administrator/finance roles and denying manager/realtor. Added organization-scoped count-first 25-row approved-account reader with minimal fields, strict schema/approval metadata validation, duplicate account/code rejection and fresh membership comparison after reads. Actual helper tests cover role/account changes, foreign/malformed records, null count, errors and real zero results. Focused tests, native TypeScript and lint pass. No screen is connected yet and no balance/payment is inferred from account registration. Native register/statement/trial balance/journal/invoice/cheque workflows and live/device/provider/release acceptance remain open. Supabase changelog Markdown was unsupported by browser and shell DNS failed; official HTML changelog and current getUser/select docs were inspected instead.


### Native approved finance account register screen

Connected signed-in account-home/Stack route for the organization-approved account register. Uses fresh administrator/finance reader, count-first 25-row FlatList, approved code/name/class/reason/approver/reference and Jamaica registration time. Shows explicit registration-versus-balance/payment semantics, bounded previous/next, refresh and loading/access-unavailable/empty handling; signed-out users go to sign-in and identity changes reset the register. Actual display/navigation and reader tests pass; native TypeScript, lint and web/iOS/Android export passed. Statement and journal links are not presented until those native destinations exist. Next: exact account statements with shared date validation and BigInt amount handling, then trial balance/account authoring/journals/invoices/cheques. Live/device/provider/release acceptance remains open.


### Native exact finance account statement reader

Added finance_account_statement RPC reader using actual shared statementQuery/formatJmdMinor and fresh finance membership before/after. Validates exact account, canonical date/currency/page/count metadata, bounded complete page, narrow journal lines, Jamaica interval timestamps, debit/credit line bounds/exclusivity, unique line identities, running and closing balances using BigInt. Preserves large aggregate strings rather than floating-point totals. Focused actual helper tests pass for large balances, foreign/malformed/account/date/balance records, zero periods and changed authority; native TypeScript and lint pass. Native statement screen/filters/register links remain next; trial balance/account authoring/posting/invoices/cheques and live/device/provider/release acceptance remain open.


### Native finance statement screen and date filters

Connected exact approved-account register links and Stack destination for finance statements. Identity/account-bound state, shared validated YYYY-MM-DD filters (up to 367 inclusive days), fresh account RPC, BigInt formatting, opening/period debit/credit/closing balances, Jamaica time, bounded journal lines, refresh/error/empty and paging controls. Explicitly explains debit-minus-credit and posted-versus-bank-settled semantics. Actual screen/filter/navigation tests, reader regression, native TypeScript, lint and web/iOS/Android export pass. A display-test loading assertion initially expected the outer node instead of its ActivityIndicator child; corrected assertion and reran successfully. Native journal details/actions, trial balance/account authoring/invoices/cheques and live/device/provider/release verification remain open.


### Native finance trial balance reader

Added finance_trial_balance RPC reader using actual shared date/amount helpers and fresh administrator/finance membership before/after. Exact through date/JMD, bounded count/page/rows, canonical nonnegative BigInt aggregate amounts, exact balanced flag, one-sided net account balances, approved metadata and duplicate identities/codes are validated. Page subtotal cannot exceed all-account totals; single-page rows reconcile exact totals. Genuine imbalance remains visible rather than being coerced to balanced; unavailable/malformed responses cannot become zero. Focused helper tests cover large amounts, invalid flags/rows/totals, exact zero, legitimate imbalance, errors and changed authority. Native TypeScript and lint pass. Trial screen/through-date controls/account links remain next; journal/account authoring/invoice/cheque and live/device/provider/release acceptance remain open.


### Native trial balance screen

Connected approved-register/Stack trial balance destination, shared through-date validation, identity-bound paging, exact BigInt totals, imbalance alert, Jamaica timestamps, refresh/error/empty and account statement navigation. Links carry the selected month/through date; statement filters validate incoming dates and safely default malformed dates. Focused trial/statement display tests, native TypeScript, lint and web/iOS/Android export pass. Journal details/actions, account registration, invoices/cheques and live/device/provider/release acceptance remain open.


### Native journal history reader and statement schema alignment

Added fresh verified finance/admin organization-scoped count-first 25-row immutable journal history reader with minimal memo/reason/actor/time/JMD fields, strict metadata/duplicate validation and post-read membership revision checks. Focused actual reader tests pass. Corrected native statement memo limit from 500 to database-approved 1000 characters, testing accepted 1000/rejected 1001; statement navigation keys now include incoming date scope so reopening the same account for a different period resets filters. Statement display tests and native lint pass; web/iOS/Android export passed, final post-navigation TypeScript check passed. Journal register/detail/reversal tracing and reviewed authoring remain next; account registration/invoice/cheque/live/device/provider/release gates remain open.


### Native exact posted journal detail reader

Added exact organization/journal metadata and bounded complete numbered journal lines (2–200), safe integer/string line amounts, positive one-sided debit/credit validation, dimension/reference checks, unique lines and BigInt balanced totals. Reads retained original/reversal relations independently within the approved organization, validates actor/reason/time and rejects self/invalid reversal chains; fresh finance membership checked after reads and missing journal. Narrow output excludes payload/transaction internals. Focused actual helper tests pass for foreign/malformed metadata/lines, amounts, imbalance, missing/error, reversal and changed authority; native TypeScript and lint pass. Native register/detail screens and statement source links remain next, followed by reviewed account/journal/reversal commands, invoices/cheques and live/device/provider/release acceptance.


### Native journal history/detail screens

Connected organization journal register (25 rows, approval actor/reason/Jamaica time, paging/refresh), exact immutable detail with full balanced lines/dimensions/request reference, account-statement links and original/reversal retained navigation. Statement entries now link directly to source journal; approved-account register links journal history and Stack routes are registered. Identity-bound loading/sign-in/error/missing/empty screens preserve approval and posting-versus-settlement semantics. Actual register/detail/source/reversal/display tests, native TypeScript, lint and web/iOS/Android export pass. Reviewed account/journal/reversal commands, invoices/cheques and broader/live/device/provider/release verification remain open.


### Native reviewed journal reversal command

Added frozen canonical reversalInput command and fresh finance authority/original-journal checks. Allows same-request replay after original reversal while rejecting reversal-of-reversal parents. reverse_finance_journal acknowledgement is verified against exact organization/original/reversal/actor/request/reason retained record and fresh resulting journal with canonical memo, approval actor/request, incoming relation, every line account/dimension and swapped amounts. Unknown writes/receipts remain uncertain; known RPC rejections are distinguished. Focused actual-validator command tests pass for replay, approval/access gates, malformed receipts/lines and uncertainty; native TypeScript and lint pass. Command is not yet exposed: explicit review/consent form is next, followed by account/journal authoring, invoices/cheques and live/device/provider/release acceptance.


### Native explicit journal reversal review controls

Connected eligible original journal detail to required reason/unchecked approval/canonical review and actual reversal command. Fixed journal reference, frozen request, duplicate/stale/unmounted write guards, sticky unknown state across later rejection and verified-receipt refresh. Hides unavailable already-reversed/reversal journal forms and explains new swapped-line journal versus refund/bank settlement. Focused review/detail/control tests, native TypeScript, lint and web/iOS/Android export pass. Reviewed account registration/journal authoring, invoices/cheques and broader/live/device/provider/release acceptance remain open.


### Native approved finance account registration command

Added frozen normalized financeAccountInput command with fresh administrator-only finance membership. author_finance_account UUID acknowledgement is verified against retained organization/account/actor/request/canonical approved payload and exact immutable current code/name/class/approver/reason, then fresh membership revision. Unknown writes/receipts preserve uncertainty; known validation/authorization/conflict failures are distinguished. Actual-validator command tests pass for normalization, approval gates, finance/manager/realtor denial, receipt/account mismatches, changed authority and uncertainty. Native TypeScript and lint pass. Command is not yet exposed: reviewed administrator account form is next; journal authoring/invoice/cheque and live/device/provider/release acceptance remain open.


### Native administrator finance account registration form

Connected administrator-only register link/Stack editor destination with fresh role read, separate ScrollView form outside virtualized records. Code/name/classification/reason/explicit approval, actual-validator normalized review, frozen request and sticky unknown retry, duplicate/stale/unmounted guards and verified-receipt register navigation. Registration-versus-balance/payment semantics are shown. Actual validator/control and register role-link tests, native TypeScript, lint and web/iOS/Android export pass. Dedicated editor access-state display verification/broader regression remain to strengthen; journal authoring/invoices/cheques/live/device/provider/release acceptance remain open.


### Native journal posting command and account editor access verification

Added actual journalInput canonical posting command with deeply frozen line array/records, fresh finance authority, exact post_finance_journal RPC and resulting complete journal actor/request/memo/reason/account/dimension/amount verification. Same-request replay remains valid if the original has subsequently been reversed, reporting current reversal state. Unknown writes/receipts remain uncertain. Focused command tests pass for balance/approval/access, frozen lines, record mismatches, advanced replay and changed authority. Dedicated account-new editor display tests confirm admin-only form, safe unavailable/loading/signed-out state and register return. Native TypeScript/lint pass; broad native regression completed (183 PASS checkpoints at its captured manifest), with subsequent account-editor and journal-command focused tests passing separately. Posting review UI/approved account/dimension selection remain next; invoices/cheques and live/device/provider/release acceptance remain open.


### Native finance property/unit dimension search reader

Added search_finance_dimensions reader for approved administrator/finance role, using existing narrowly scoped RPC rather than management-only direct property access. Validates kind, trimmed search up to 120 characters, unit property UUID/property search null scope, maximum 25 minimal label/id items and explicit more-results state, duplicates/malformed responses and fresh membership before/after. Focused helper tests pass for exact RPC/unit binding, scope/input rejection, foreign/malformed/duplicate metadata, errors versus empty and changed authority. Native TypeScript and lint pass. Account/property/unit selector UI and posting review remain next; invoices/cheques and live/device/provider/release acceptance remain open.


### Native approved finance account selector

Added exact organization-scoped approved account reader (minimal code/name/class/id) with fresh finance membership before/after selection. Added 25-row account picker using approved register, bounded paging, selected-account fresh recheck, duplicate lock, unmount suppression and safe loading/error/empty/refresh. Focused actual reader and picker tests pass; native TypeScript and lint pass. Picker is not yet exposed in posting: property/unit selector and full multi-line posting editor/review remain next. Invoices/cheques and live/device/provider/release acceptance remain open.


### Native finance property/unit search selector

Added explicit finance dimension search picker using existing RPC labels and retained fresh read membership scope. Up to 25 choices with more-results refinement disclosure, query snapshots, duplicate/completion locks, selected-member organization/role/revision recheck, unmount suppression and unavailable/loading/empty states. Reader now returns authority snapshot only for local selection comparison; no authority is accepted from user inputs. Focused picker/reader tests and native TypeScript pass; removed redundant cleanup epoch increment that lint flagged (mounted guard retains unmount protection), focused test and clean lint rerun passed. Selector remains unconnected until multi-line posting editor provides per-line/owner/kind/property keys and modal selection; journal posting UI/review, invoices/cheques and live/device/provider/release acceptance remain open.


### Native multi-line journal draft model

Added immutable draft lines with stable UUID identities, approved account/property/unit choices, property-change unit reset, side/decimal editing, 2–200 line add/remove guards and shared jmdMinor exact conversion into actual deeply frozen financeJournalCommand review. No draft performs a write. Focused tests use actual command/validators and cover precision, approval/balance, absent selections, stale line keys, property/unit reset and invalid amounts. An initial test harness syntax error was corrected; successful rerun, native TypeScript and lint pass. Full editor/selector orchestration and final review/posting UI remain next; invoices/cheques/live/device/provider/release acceptance remain open.


### Native multi-line journal posting editor

Connected finance journal-new route/history link to fresh finance access and full ScrollView editor. Stable line UUIDs, 2–200 add/remove, approved account/property/unit modal pickers, per-selection tokens, stale cancellation rejection, property-change unit reset, exact JMD input, explicit per-line approval, deeply frozen canonical review and actual posting command. Review displays exact accounts/dimensions/amounts; duplicate/unknown retries preserve reviewed request and verified receipt links the recorded journal/current reversal state. Focused editor tests cover selectors/stale callbacks, amount/balance/approval review, duplicate locks and sticky uncertain retry. Native TypeScript, lint and web/iOS/Android export pass. Further line/dimension/unmount/route integration tests and broader live/device acceptance remain next; invoices/cheques/provider/release gates remain open.


### Journal editor approval and selection regression follow-up

Memo/reason edits now invalidate prior approval and are blocked while a selector is open. Add/remove handlers enforce current 2–200 line bounds independently of disabled controls. Expanded actual-editor tests cover minimum-line callbacks, add/remove, property-bound unit selection, canceled stale unit callbacks, clearing property/unit, and memo approval reset; added actual journal-new route tests for finance/admin access, denied/missing/error/loading states and owner-keyed sign-in flow. Both focused tests and native TypeScript pass. Native lint also passed. No live database write, email, deployment or device acceptance was performed; invoice/cheque native workflows and external launch gates remain open.


### Native invoice authority and register reader

Implemented dedicated fresh invoiceAccess preserving existing admin/manager/finance read scope, independently from admin/finance journal access. Added organization-scoped count-first 25-row invoice register reader with optional validated state filter, exact JMD integer amounts, minimal returned fields, complete-page/count validation, duplicate rejection, and post-read membership organization/role/revision recheck. Focused tests exercise actual access/reader: all three permitted roles, realtor denial, unconfirmed/anonymous/wrong identity, invalid amounts/states/currency/records, filter mismatch, incomplete pages, errors, empty register and changed membership. Focused test, native TypeScript and lint pass. Reader is not yet connected to a native screen. Next: invoice register/detail/history UI, retained evidence and independent review/posting commands, then cheque native workflows. Live/device/release verification remains outstanding. No database mutation or deployment this cycle.


### Native invoice register screen

Connected owner-keyed native invoice register and home/stack navigation. Accessible all/submitted/under-review/approved/rejected filters reset the paged register using owner/status identity, with guarded previous/next and explicit refresh. Virtualized 25-row display preserves precise JMD amounts and Jamaica submission timestamps, distinguishes approval from ledger posting/payment, and handles unavailable/empty/loading states. Actual-screen focused test passes for amount precision, semantic labels, paging guards, filter reset, sign-in/identity, home/stack wiring; native TypeScript passes. Native lint passed. First all-platform export exited 139 after web/iOS bundle messages; no all-platform success claimed. Fresh retry completed successfully for web/iOS/Android at /private/tmp/openhouse-native-invoice-register-export-retry. Native invoice detail/history/evidence, independent review/posting, cheque workflows and live/device/release gates remain open.


### Native exact invoice detail reader

Added exact organization/invoice detail reader with fresh invoice membership before/after, narrow retained fields, exact JMD amount, property/work parent binding, version/state invariants matching current immutable transition SQL, paired actor/time checks and independent submitter/reviewer/approver validation. Uses actual shared invoiceActions for eligible review/approve/reject actions; manager and original submitter cannot review, original reviewer cannot approve. Focused actual-reader/shared-action tests pass for exact/max amount, malformed records, independent review/approval, rejected versions, missing/error/changed membership. Native TypeScript and lint passed. Reader is not yet connected; next are detail/history/evidence screens and actual verified commands. Production/live/device gates remain open; no mutation/deployment.


### Native complete invoice audit reader

Added organization-scoped invoice history reader verifying complete current 1–3-event sequence, contiguous revisions/state transitions, independent actors matched to retained invoice, minimal audit metadata and distinct event/request references. Reads one extra row to detect malformed excess history, then rechecks current invoice revision/state and membership organization/role/revision. Focused tests pass for approved/rejected histories, malformed/missing/duplicate/scope records and changed access. Removed timestamp ordering assumptions from detail/history: statement_timestamp precedes lock acquisition and does not prove commit sequence; valid timestamps remain checked, while immutable revisions determine order. Focused detail/history tests pass; final native TypeScript/lint rerun passed. Detail/history UI, reviewed evidence and commands remain next; live/device/release gates remain open.


### Native invoice detail and complete history screen

Connected invoice detail route to register-row exact invoice IDs and Stack. Owner/invoice-keyed loader uses verified complete history reader; bounded ScrollView shows exact JMD amount, revision/status, submitter/reviewer/approver with Jamaica times, immutable property/work allocations and all retained audit reasons/actors/request references. Clear approval-versus-ledger/payment semantics; unavailable/missing/loading and refresh states do not imply an absent audit trail. Actual screen/register tests, native TypeScript and lint pass. Web/iOS/Android export completed successfully at /private/tmp/openhouse-native-invoice-detail-export. Reviewed evidence UI and independent commands/posting remain next, followed by cheque and live/device/release gates.


### Native invoice certified/frozen document reader

Added organization/invoice-scoped document reader with fresh verified membership and current invoice before/after. Maximum ten certified uploaded files, valid names/types/sizes/hashes and exact original submitter binding; reviewed invoices require complete frozen version-2 snapshot matching every source ID, kind, name, MIME, hash and size. Snapshot mandatory even after a reviewed invoice is rejected. Unreviewed invoices cannot claim a frozen snapshot. Output omits storage paths and hashes; sourceReady distinguishes absent certified invoice from unavailable metadata. Focused tests pass for approved/submitted/empty records, malformed metadata, altered/missing snapshots and changed access. Native TypeScript and lint passed. Reader is not yet connected; next are document display/private download, reservation/upload and independent review controls. Live Storage/device/release gates remain open.


### Native invoice certified document display

Connected version/owner/invoice-keyed certified document component to invoice detail. Displays minimal filename/kind/MIME/size/reference, frozen review-version-2 explanation and source readiness, preserving approved snapshot meaning. Mismatched invoice revision, unavailable metadata and loading are explicit; empty certified source is distinguished from error, and certification does not claim verified vendor liability/payment. Actual component/detail tests pass. Native TypeScript, lint and web/iOS/Android export passed at /private/tmp/openhouse-native-invoice-documents-export. Private document download, reservations/upload and independent finance decisions remain next, with live Storage/device/release acceptance open.


### Native private invoice document signing

Added fresh membership/certified-document signing helper. Selected exact invoice/file must be present in complete source/snapshot reader; exact uploaded document org/invoice/submitter binding and retained path/name are rechecked. Authenticated Storage signing expires in 120 seconds; HTTPS, fixed project host, exact vendor-invoice-evidence bucket/path and token are required. After signing, complete evidence/current invoice/membership and selected metadata/path are revalidated before returning URL. No secret key or signed-link logging. Focused tests pass for exact signing and revoked/foreign/withdrawn/changed revision or malformed-link rejection. Native TypeScript and lint passed. Helper is not yet connected to device open UI; live Storage/device acceptance remains open, alongside uploads/review/posting/cheques/release work.


### Native private invoice document opening

Connected certified document rows to owner/invoice/version/document-keyed FinanceInvoiceOpen using actual private signing helper and Expo Linking. Duplicate-tap lock, fresh short-lived link per attempt, failure retry and mounted guards prevent late device/browser handoff after leaving the screen. UI reports browser handoff rather than claiming a downloaded/read document; signed URLs are never rendered or logged. Actual-control and document display tests pass for duplicate/failure/retry/unmount behavior. Native TypeScript, lint and web/iOS/Android export passed at /private/tmp/openhouse-native-invoice-open-export. Live Storage/device acceptance remains unverified; native uploads/reservations, independent review/posting, cheque workflows and external release gates remain next.


### Native independent invoice decision command

Added deeply canonical frozen review/approve/reject command using actual shared invoiceInput. Requires fresh admin/finance authority, independent submitter/reviewer gates, and certified source (frozen for approval); RPC maintains transition, concurrency and idempotency enforcement. Successful acknowledgement is verified against retained exact audit actor/request/action/revision/state/reason/payload, complete current history and frozen source. Advanced-state replay reports original recorded decision plus current invoice state, preserving retryability. Known database rejection versus uncertain write/receipt failures are explicit. Focused actual-validator tests pass for approval normalization, role/source gates, exact audited receipt, advanced-state replay and malformed/changed-access/error outcomes. Native TypeScript and lint passed. Focused tests also cover approve/reject receipts and reject approval by the original reviewer. Decision UI and invoice uploads/reservations remain next; live multiactor database/device acceptance and full release remain open.


### Native invoice decision review controls

Connected fresh document-reader eligible actions to native invoice decision form. Explicit approval and reason, canonical reviewed invoice/revision/action/request, reason edits invalidate approval, duplicate/stale/unmount/completion locks, sticky uncertain retries and verified original/current-state receipt. Review action withheld without certified source; manager/submitter/reviewer exclusions come from actual shared action rules and command revalidation. Actual-control/document tests passed after fixing harness handling of dynamic text children; native TypeScript and lint passed. Web/iOS/Android export completed at /private/tmp/openhouse-native-invoice-review-export. Parent invoice refresh propagation should be completed before live acceptance: decision refresh currently reloads the documents panel and may expose the revision-mismatch refresh message until the main invoice is refreshed. Native uploads/reservations and invoice ledger posting/cheque workflows remain next; live multiactor/device/Storage/release gates remain open.


### Native invoice decision parent refresh

Completed parent invoice refresh propagation: decision receipt Refresh invoice now calls the full detail/history loader, remounting version-keyed documents/actions when the revision advances. Documents-only refresh remains local. Actual detail/document tests verify both callback layers and distinguish full invoice refresh from panel refresh. Focused tests, native TypeScript and lint passed. This resolves the prior documented parent-refresh gap. Native invoice uploads/reservations and ledger posting, cheque workflows and full live/device/release gates remain open.


### Native invoice evidence upload endpoint

Added bearer-authenticated /api/native/invoice-evidence POST, using existing nativeServerIdentity, shared invoiceEvidenceInput, database reservation/withdrawal RPCs and server-only source-format/hash certification. Fresh verified admin/manager/finance membership with exact revision, organization/owner document binding, strict reservation ID/state/canonical path, private/no-store replies, and identity/membership recheck before returning upload token or certifying bytes. Existing RPCs retain source ownership/review-stage/concurrency limits; no new storage policy or schema grants. Focused actual-route/shared-validation tests pass for identity/roles/configuration, malformed reservations, invalid file bytes, server-derived certification and changed identity suppression. Root TypeScript passed; production build running. Native reservation/upload client/UI and recovery records remain next; server credential, live Storage/device/release gates remain open.


### Native invoice upload client

Added immutable invoice/supporting upload attempts using actual documentFile validation and owner/submitted invoice gate. HTTPS bearer transport rejects redirects; reservation preserves request nonce and checks canonical invoice/document extension path, signed upload uses exact byte count and no overwrite, and server certification result is rechecked against certified document reader. Focused actual-client/document-validator tests pass for metadata, secure transport, exact bytes/no-overwrite, reservation/finalization and denied identity. Initial write targeted a duplicated mobile path and failed before creating a file; corrected write completed. Native TypeScript and lint passed. Prior root production build 56471 remains live, not restarted or claimed successful. Native file picker/recovery/withdrawal and invoice intake/posting/cheques/live/device/release gates remain open.


### Native invoice upload recovery records

Added original-submitters-only reservation reader with fresh invoice/staff membership before/after, organization/user/invoice scoping, count-first complete 25-row pages and metadata validation. Preserves reserved/uploaded/withdrawn/expired states and reservation expiry; no paths/tokens returned. Current revision/state and membership revision must remain unchanged. Focused tests pass for recovery states, scope, unavailable/incomplete/invalid records and changed access; existing upload-client tests pass after replacing misleading internal contractor naming with ownSubmittedInvoice. Native TypeScript and lint passed. Root production build handle 56471 remains live without terminal result; not restarted. Recovery controls/file picker/withdrawal, invoice intake/posting and remaining full-production gates remain open.


### Native audited invoice upload withdrawal

Added own-submitted-invoice withdrawal command using existing authenticated withdraw_invoice_evidence RPC. Exact document/user/org/invoice binding, retained withdrawn state and retained actor/document withdrawal audit must match; fresh invoice state/version and membership scope/revision are rechecked. Already-withdrawn requests verify the same retained record without another mutation. Focused tests pass for exact RPC, owner/scope denial, replay, missing audit, failed RPC and changed access. Native TypeScript and lint passed. Root build handle 56471 remains live; no terminal result or restart. Recovery UI/file picker, invoice intake/ledger posting and remaining full-production/live/device gates remain open.


### Native invoice reservation recovery controls

Added InvoiceUploadCertify and InvoiceUploadWithdraw controls invoking verified invoice upload/withdrawal helpers. Explicit withdrawal confirmation; duplicate/completion locks; retry same retained document after uncertain outcomes; unmount suppresses late state/refresh effects; certification clearly separates file upload from invoice approval and requires secure application origin. Focused controls tests pass for retries, confirmed readback, refresh and unmount; native TypeScript and lint passed. Controls not yet wired to submitter reservation list. Root build handle 56471 remains live without terminal output, not restarted. Native reservation list/file picker integration, invoice intake/ledger/cheques and full live/device/release gates remain open.


### Native submitter invoice upload recovery list

Connected submitter-only retained reservation list inside certified document panel. Complete 25-row scoped records with expiry/Jamaica time, explicit reserved-versus-certified explanation, finalize reserved files and withdraw reserved/uploaded only while submitted; post-review/rejection controls closed. Revision mismatch requires parent invoice refresh, command completion refreshes whole invoice, record-only refresh remains local; paging guards prevent invalid callbacks. Actual recovery/document tests pass for finalize/withdraw eligibility, reviewed lock, parent refresh, revision/error/loading. Native TypeScript, lint and web/iOS/Android export passed at /private/tmp/openhouse-native-invoice-recovery-export. File picker/upload intake, invoice creation/ledger and cheque/live/device/release gates remain next; root production build 56471 remains live without terminal result.

### Native invoice picker and confirmation
Implemented a private invoice document picker for the original submitter while an invoice remains submitted. Vendor invoice/supporting classification is frozen with the selected file and stable upload request. PDF/JPEG/PNG size and signature checks run before explicit confirmation. Uncertain storage retains the request, offers certification without reupload, and uses the existing no-overwrite reservation workflow. Completion refreshes the parent invoice. Focused picker/recovery and document display controls pass. Native typecheck, lint and all-platform export are running; live device and server credentials remain unverified.
Native picker typecheck and lint passed. First all-platform export failed terminally: Hermes compiler SIGSEGV during native bytecode compilation after web bundling. A retry is running; native export success is not yet confirmed.

### Native invoice submission transport
The invoice picker export retry passed terminally for web, iOS and Android at /private/tmp/openhouse-native-invoice-picker-export-retry. Root Next production build session 56471 also completed successfully, including TypeScript and 73 generated pages.
Added native invoice submission normalization and authenticated RPC transport for verified administrator, manager and finance membership. Submission freezes normalized metadata and exact whole-minor-unit JMD amounts, validates the retained actor/request audit payload and immutable invoice fields, and accepts original submission replay after later independent review. Unknown response/readback failures preserve the request for retry; changed membership suppresses receipt acceptance. Focused submission verification passed. Submission form and organization-bound property/work-order selection remain next; live production acceptance is still incomplete.

### Invoice binding search
Applied migration 20261007220139_invoice_binding_search to the linked Open House Supabase project. A public security-invoker wrapper calls a private guarded search for verified administrator/manager/finance organization access. Results expose only up to 25 property/work-order IDs and labels plus a more flag; work-order searches require a property in the same organization and filter both organization and property. Existing broad table policies were not expanded. Live checks confirm anonymous/service-role execute grants are absent, authenticated grants present, fixed empty search paths, and unauthenticated invocation denied. Added native bounded result validation and membership revalidation plus a label picker. Focused reader tests pass. Complete authenticated cross-organization live acceptance and creation-form integration remain outstanding.

### Native invoice creation flow
Added /finance-invoice-new and register navigation for verified administrator, manager and finance users. The form selects organization property/work-order labels, clears a work order when its property changes, supports organization-wide invoices, parses exact JMD minor units, invalidates confirmation on edits, and reviews frozen metadata before submission. Duplicate/stale submission guards and sticky unknown-response handling preserve the same request. Verified receipts link to the invoice document workflow. Focused control tests pass for exact amounts, bindings, approval/review, duplicates, uncertainty and document handoff. Typecheck/lint and all-platform export are running; live cross-role/device acceptance remains outstanding.

### Native invoice ledger linkage
Invoice creation export session 99623 completed successfully for web/iOS/Android at /private/tmp/openhouse-native-invoice-create-export. Added finance-only invoice posting readback against the existing immutable posting table. It validates exact organization/invoice scope, independent approval event, frozen certified source, journal actor/request/reason/memo, exactly two approved-amount lines and property allocation. Original journal reversal history remains attached; reversal does not remove the original invoice posting. Focused tests pass for maximum exact amounts, mismatches, missing source/audit, reversals and changed membership. Posting UI and command remain next; live end-to-end acceptance is not established by mocked reader tests.

### Native approved invoice posting command
Added frozen normalized posting command using the existing authoritative post_approved_vendor_invoice RPC. Fresh finance authority, approved invoice revision, frozen certified source, distinct asset/expense debit and liability credit are required. An existing posting permits only exact same actor/request/accounts/reason replay; another posting is denied. Receipt readback verifies the exact retained journal, actor, nonce, revision and account binding through the full source/journal reader; changed membership suppresses success. Reversal history does not create a second posting opportunity. Focused command tests pass including known/unknown errors and retained replay. Native posting selection/confirmation UI and live acceptance remain next.

### Native invoice posting interface
Connected finance-only invoice ledger display and approved invoice posting confirmation to the invoice detail page. Approved account selection uses a modal to avoid nested virtualized lists; selected debit must be asset/expense and credit liability. Changes invalidate allocation confirmation. Review freezes the invoice/version/accounts/reason/request; duplicate and stale callbacks are guarded, and unknown results preserve the same request even after later known rejection. Posted invoices link to original/reversal journals and never offer another posting. Invoice display and posting control tests pass. Typecheck/lint and all-platform export are running. Live authenticated/device and accounting acceptance remain required.

### Native cheque custody register
Invoice ledger posting export session 43648 passed for web, iOS and Android at /private/tmp/openhouse-native-invoice-posting-export. Added a finance-only cheque custody register reader and screen with state filters, bounded complete pages, exact JMD amounts, narrow organization scope, validated payer/bank/reference/property metadata and membership revision revalidation. Received, deposited, cleared, returned and cancelled states remain distinct; custody/bank evidence/accounting/reconciliation semantics are explicit. Focused reader tests pass including manager/realtor denial and malformed/incomplete records. Cheque detail audit, private bank evidence, controlled transitions and accounting interfaces remain to build; the register does not claim settlement verification.

### Native cheque detail and custody chain
Cheque register export session 96080 passed for web/iOS/Android at /private/tmp/openhouse-native-cheque-register-export. Added exact organization-scoped cheque detail validation and complete bounded custody history (maximum four events, one extra fetched to detect corruption). State/revision pairs, immutable payer/bank/reference/property, exact JMD amount and cancellation timestamps are validated. History validates the original receiver, sequential versions, exact prior/new state transitions and unique actor/request references, then rereads current detail and membership. Timestamp ordering is not used as a substitute for authoritative revision order. Focused tests use actual detail and history implementations across receipt/deposit/clear/return/cancel, malformed amounts/metadata, missing/duplicate/invalid chains and changed authority. Native detail UI, bank evidence snapshots and controlled decisions remain outstanding.

### Native cheque custody detail screen
Connected /finance-cheque from cheque register rows and added native navigation title. The screen reads the full validated custody chain, presents payer/bank/reference/exact JMD amount, property/receiver and Jamaica receipt/cancellation times, and all retained action/reason/actor/request events. Invalid references, missing history, unverified access and loading states are handled. Custody decisions remain distinct from ledger posting and bank reconciliation. Display verification passes for metadata, sequence presentation, routing, refresh and error/sign-in states. Typecheck/lint and all-platform export are running; bank evidence snapshot review and controlled decisions remain next.

### Native frozen bank decision evidence
Cheque detail export session 65980 passed for web/iOS/Android at /private/tmp/openhouse-native-cheque-detail-export. Added a bounded complete frozen bank history reader. Every deposit/clearance/return event must have exactly one snapshot tied to its revision and document kind, with certified source filename/MIME/hash/size and retained bank reference matching the authoritative event payload. Purged/mismatched sources, duplicate event/document bindings and changed authority are rejected. Returned UI metadata excludes hashes/storage paths. Focused tests pass for source/audit mismatches, incomplete snapshots, malformed metadata, empty receipt history and membership changes. This validates retained recorded evidence; actual bank settlement and operational reconciliation still need acceptance.

### Native frozen bank evidence display
Corrected bank-history typecheck passed. Connected verified frozen bank evidence metadata to cheque detail, keyed by owner/cheque revision with parent refresh propagation. Deposit/clearance/return snapshots display filename, MIME/size, bank reference, evidence reference and Jamaica freeze time. Empty, loading, error and revision mismatch states are explicit. Copy distinguishes format certification from independent bank verification and reconciliation. Bank display and cheque detail tests pass. Private file opening, certified upload/reservation recovery, custody decisions and cheque ledger interfaces remain outstanding.

### Native frozen bank private document access
Bank display export session 49860 passed for web/iOS/Android at /private/tmp/openhouse-native-cheque-bank-display-export. Added private open actions for frozen decision documents. Signing verifies the complete snapshot/source/audit history and exact canonical cheque/document object path, obtains a 120-second private-bucket link, validates HTTPS project host/bucket/path/token, and rereads source, custody revision and finance membership before returning. UI guards duplicate requests and unmount handoff, requests a fresh link per attempt and reports device handoff without claiming a completed download. Private URLs are not rendered/logged. Signing/open/display tests pass; live Storage/device acceptance is outstanding.

### Native certified bank decision choices
Private cheque open export session 68803 passed for web/iOS/Android at /private/tmp/openhouse-native-cheque-private-open-export. Added bounded certified cheque evidence metadata readback with current finance authority and complete frozen-source crosschecks. Uploaded private documents validate exact size/MIME/hash/name/uploader/organization and nonpurged state; UI data omits hashes/paths. Frozen decisions identify used documents; available choices include only unused deposit evidence at receipt, clearance/return evidence after deposit, and return evidence after clearance. Terminal records offer no bank decisions. The authoritative RPC still enforces bank action, reservations and transaction concurrency. Focused tests pass; bank decision UI/commands and upload recovery remain next.

### Native cheque custody review controls — 2026-10-07

Added the native cheque detail decision form backed by freshly verified certified evidence and state-specific choices. Users review the exact cheque revision, reason, bank reference and evidence before confirmation. Submission freezes the request, suppresses duplicate/stale presses, and retains uncertainty across subsequent failures for same-request retry. Cancellation requires no bank evidence; deposit, clearance and return require matching unused certified source documents. Receipt confirmation includes retained audit and bank snapshot verification through the existing command service. This recovery is scoped to the mounted screen; durable restart recovery, native bank document upload, and accounting controls remain unfinished.

Checks: native TypeScript and zero-warning lint passed; cheque command, evidence and review-control behavioural verifiers passed. The review-control verifier covers explicit approval, cancellation review, stale input, duplicate submission, uncertain retry and unmount handling; it does not prove real-device bank selection or upload. iOS/Android/web export started as process 36105 and requires terminal verification. No production deployment of these local mobile changes has been performed.

### Native cheque recovery persistence foundation — 2026-10-07

Previous cheque review export process 36105 terminated successfully: iOS, Android and web exported. Added an injected persistent-store service for frozen cheque requests, scoped by account and cheque, with canonical command verification, serialized operations, write/readback verification and exact-request deletion. Existing unresolved requests cannot be replaced, malformed storage fails closed, and storage failures propagate. Focused verifier covers owner isolation, same-request reuse, competing request protection, corrupt storage and lost writes. This service is not yet connected to encrypted device storage or the form; restart recovery remains incomplete until that integration and UI tests pass. The previous mounted-screen recovery remains the current UI behavior.

### Native visual discovery first pass — October 7, 2026

Replaced the native entry screen's operational link list with branded discovery: supplied logo, clear search and category links, photographic demo property cards and a realtor introduction panel. Preserved the operational/account screen at /account. Added native demo collection search and intent filtering, reusable property cards with image failure fallback, and native demo details with exact illustrative prices, facts and approximate-area map handoff. Demo viewing/application and wider role exploration explicitly open the web simulation; these are not native-complete demo flows. Full native brand typography, persistent navigation, realtor polish, resident/staff dashboards and actual device visual acceptance remain incomplete. Export process 58993 and typecheck/lint were started and require terminal verification; this entry does not assert client-ready mobile UX.

### Native demo realtor guided presentation — October 7, 2026

Discovery export process 58993 passed for all three platforms. Added six native fictional realtor profile cards and a guided five-question working-preference match experience using the shared demo ranking. Choice-required navigation, complete preference handoff, explained results and explicit browser prospect-simulation links pass the focused UI verifier. Connected the demo matching route from native discovery while retaining a separate live directory link. No real assignment/enquiry is performed. Browser visual review failed twice because the computer-use kernel exited; actual rendered/device review remains unproven. Native design remains incomplete (brand fonts, persistent navigation, live directory/dashboard refinements and client/device acceptance). This is incremental UI work, not a claim of client-ready native delivery.

### Native brand typography and persistent discovery navigation — October 7, 2026

Realtor export process 36631 passed for web/iOS/Android. Added bundled Playfair Display semibold headings and Inter body/strong fonts via SDK 57 expo-font, with loading presentation and system fallback on font load failure. Runtime loading supports the current Expo Go preview; font plugin registered manually in dynamic app.config.ts after install successfully added packages but returned a configuration-write error. Added persistent Home/Search/Saved/Enquiries/Account destinations with safe-area padding, accessible selection and auth-route exclusion. Existing Stack routes remain intact; operations are retained in Account. Focused navigation and guided-match checks pass. Actual iPhone typography, keyboard/navigation, large-text and client visual acceptance remain required. Platform export for this connected font/navigation graph has started and requires terminal verification.

### Native account workspace hierarchy — October 7, 2026

Brand-font/navigation export process 26775 passed for all three platforms. Reorganized the native account screen into a verified-account introduction, six personal journey rows and collapsed team/property tool groups. Existing finance, management, access-administration, owner, contractor and security destinations remain reachable; their own existing authorization checks still enforce private data access. Group visibility is not proof of entitlement; copy states that destination authorization applies. Only one group expands at a time. Signed-out presentation provides sign-in, registration and labelled demo routes. No activity counts or account-specific metrics were fabricated. Focused workspace controls and lint pass; final typecheck and all-platform export were started for the connected account graph. Native visual/device and signed-in cross-role acceptance remain open.

### Native property-bound demo journey — October 7, 2026

Account final typecheck 63705 and all-platform export 77323 passed. Added a native property-specific prospect/realtor/management simulation for viewing request, confirmation, sample checklist, submission and review. Rental content describes an application; sale content describes a purchase enquiry. Explicit demo copy states no real data, email/files, legal agreement, payment or reservation is created. Actions are gated by role and current prerequisites, progress cannot be applied to another property, duplicate actions are no-ops and a local reset is available. Focused actual reducer checks pass for property isolation, wrong roles, prerequisites and duplicate handling. Connected to the native detail screen with property-keyed reset. This moves the viewing/application preview into the native screen; full resident lifecycle and cross-screen persistent demo state remain unfinished. Connected typecheck/lint are pending terminal results; rendered/device acceptance remains open.

### Native demo map browsing — October 7, 2026

Property journey export 24551 passed on all three platforms. Live iPhone Metro process 74809 reported successful iOS bundles; this is runtime delivery evidence, not visual/user acceptance. Added native demo collection list/map switching, shared filtered property coverage, bounds-based map region, labelled approximate demo markers and selected-property cards. Map remounts when filtered IDs change to avoid stale region/selection. No device location is requested. Web fallback lists approximate-area links and an explicit browser interactive-map handoff. Focused component checks pass for marker coverage, selected card, no-location flags, bounds and empty state. Typecheck/lint and all-platform map export require terminal verification. Real-device map tiles, gesture/accessibility behavior and actual visual acceptance remain open.

### Native session demo shortlist — October 7, 2026

Demo map export process 62351 passed on web, iOS and Android. Added a shared app-session shortlist provider restricted to known fictional property IDs, card/detail save-remove controls and a native demo-saved screen. Cross-screen saves remain separate from the verified-account saved_listings workflow; links expose both collections explicitly. Empty-state guidance, count, selected button state and clear-demo action are included. Provider tests pass for shared state, invalid IDs, removal, selected-state and session clear. Connected typecheck/lint and all-platform export require terminal verification. This state is intentionally session-only and contains no real user or backend records. Device visual acceptance and native resident/staff demo journeys remain unfinished.

### Mobile branding pass — 7 October 2026

Added a brand-derived navy/white app icon, configured native logo splash held through font loading, and restyled shared navigation headers. Home no longer displays a duplicate navigation title and respects the top safe area. Sign-in and registration now share a branded keyboard-aware form shell with labelled inputs, password visibility, disabled submission states and expandable recovery/confirmation help, while retaining existing account authorization and invitation logic. Mobile TypeScript and lint passed; Expo public config resolved and all-platform export completed. These changes are local. Device visual acceptance and installed-release splash/icon verification remain outstanding; Expo Go is not a complete launch-screen preview.

### Native navigation and installed-preview setup — 7 October 2026

Previous goal turn made concrete progress: configured branded icon/splash and implemented branded authentication/header UI. Continued with Ionicons from the current Expo-recommended icon-pack package, preloaded alongside brand fonts and configured its native plugin. Replaced bottom-navigation text glyphs and corrected selected destinations for demo shortlist, realtor discovery and private account workflows. Focused navigation checks, native TypeScript, lint, public config resolution and iOS/Android/web export passed. Added EAS preview, simulator and production profiles and updated the native README with the actual implementation state and required installed-client-preview inputs. JSON parsing passed; no EAS project, credentials, signed build or client install URL was created. Device visual/permission/role acceptance and external launch inputs remain open. Full production goal remains active.

### Cheque recovery verification — 7 October 2026

Previous goal turn made progress on native navigation and installed-preview build profiles. Resumed the unfinished finance verification work: updated the cheque-review interaction harness for the recovery-aware loader and asynchronous persistence. It now proves persistence occurs before sending, duplicate suppression, frozen retry after uncertainty and subsequent known rejection, retention after unmount, recovered-screen edit lock and exact-payload replay, and cleanup after a verified receipt. The recovery-store check now uses the actual native command validator and shared custody input validation instead of its former normalized mock; added rejection of whitespace-normalized, invalid-version, unapproved, different-cheque and extra-field retained payloads. Both focused checks passed. No live cheque, finance record, email or deployment changed. Native device storage and signed-in production acceptance remain open; full production goal remains active.

### Cheque recovery failure UX — 7 October 2026

Previous goal turn made progress by strengthening interrupted-request and canonical-storage verification. This increment explicitly gates browser cheque submission because encrypted native recovery is unavailable on web; the preview explains the installed-app requirement while retained custody history remains independently readable. Native recovery/document failure now offers a dedicated retry and explains that unresolved requests must be recovered before another decision. Interaction checks cover browser denial and native recovery retry availability with no submission controls. Native TypeScript, lint, all-platform Expo export and diff whitespace check passed. No live custody mutation, email, native binary distribution or deployment occurred. Signed-in, physical-device recovery and broader launch acceptance remain required; full objective remains active.

### Review certified bank documents before custody approval — 7 October 2026

Previous goal turn made progress on explicit browser recovery restrictions and native retry handling. Found and closed a substantive native approval gap: eligible certified bank documents could be selected but only frozen documents were downloadable. The decision form now provides a private-document action for each eligible source, bound to the verified owner, cheque and document. The download adapter reads the complete certified-source evidence model, retaining frozen-source validation and fresh authority/document/revision checks; it supports unused documents before approval and frozen documents afterward. Focused checks passed unused/frozen source signing, exact org/host/bucket/path, 120-second expiry, changed/withdrawn/foreign access denial, control binding, duplicate/unmount open suppression and retained request behavior. Native TypeScript, lint, all-platform export and diff whitespace checks passed. No real bank document was opened, live cheque mutated or deployment performed. Physical-device and signed-in Storage/provider acceptance remain open; full production goal remains active.

### Release regression and CI integration — 7 October 2026

Previous goal turn closed the pre-approval native bank-document review gap. Registered the new mobile discovery/navigation/account/map/shortlist and encrypted cheque recovery checks in the standard regression suite. Split the oversized 226-check native application command into application, operations and finance groups while retaining every command. Updated stale sign-in shell/submit-button assumptions and cheque review display bindings. The initial complete suite passed 53/54 groups, stopping native applications at the obsolete sign-in harness; after fixing it, the native rerun exposed stale homepage finance-link assertions and a genuine missing journal/trial navigation path. Restored journal history/trial balance to the Finance workspace and checked its rendered destinations. The later finance run exposed an obsolete missing cheque-review mock; its fixed record/revision binding and all remaining cheque checks passed. Native TypeScript, lint and all-platform export passed after navigation restoration. CI now installs locked dependencies, runs the regression suite and adds a separate mobile typecheck/lint/all-platform export job, including codex branches. CI YAML parsing and whitespace validation passed locally. A fresh full suite is running; do not claim its final result before observing the process. GitHub CI has not run these local changes. Full production goal remains active.

### Full regression release checkpoint — 7 October 2026

Previous goal turn integrated regression/CI checks and restored finance navigation. Observed the fresh standard npm test process exit 0: all 56/56 verification groups passed, including separated native applications/operations/finance and new mobile/recovery groups. Verified the authorized Vercel project/team/framework through the authenticated connector and the remote main revision as a05c03c308d61312c51539efa2819c02c57e504f. Corrected contradictory release documentation to use the actual authorized project and production origin. The former web build handle completed with exit 0; a fresh current web build is still running and must be observed before pushing this release. Native installed-binary acceptance and the full external/lifecycle launch requirements remain open.

### Authorized production release observed — 7 October 2026

Previous goal turn was a verified wait on the active local web compiler, including a short stack sample showing SWC compilation. Observed that same build handle finish with exit 0. Pushed verified commit 1f4985ae37c3ce97652995ea701e49a364d0d425 to remote main without forcing. Authenticated Vercel inspection confirms the resulting deployment dpl_7JjoZjgpjo28VH1X8Sxdx3Rjo8VS is READY for production on openhouse-realty-i43c with www.openhousejamaica.com, openhousejamaica.com and project aliases assigned. GitHub CI run 37708597017 is in progress; cloud mobile TypeScript and lint passed, export is running, web regression is running and web build remains queued behind it. This Git/Vercel release does not distribute an installed mobile binary. Full production launch and physical-device/business acceptance remain open.

### Native bank-document upload API — 7 October 2026

Previous goal turn made release progress: local production build passed, commit 1f4985a reached main, correct Vercel production deployment became READY and public homepage/demo pages returned 200. GitHub cloud mobile job has now completed successfully, including locked installation, TypeScript, lint and all-platform export. Implemented the native cheque-evidence bearer endpoint using the existing remotely verified identity/RLS-client pattern. Admin and finance roles are allowed; management/realtor access is denied. Reservations derive actor/organization in existing database RPCs, require exact cheque/document/MIME object paths, prohibit replacement uploads and recheck identity/membership before releasing tokens. Certification verifies exact stored byte size and format, computes its digest on the server and passes the verified actor to the existing privileged certification RPC. Added exact source-path checks before reading evidence bytes. Focused API/shared native auth/invoice regressions, root TypeScript and whitespace checks passed. Registered the new API check in native finance regression. Fresh web build is running. Native picker/reservation/recovery/withdrawal controls and live credential/Storage/device acceptance remain unfinished; this endpoint is local and has not been deployed. Full production goal remains active.

### Native bank-upload transport and cloud CI — 7 October 2026

Previous goal turn implemented the native cheque-evidence API and observed cloud mobile verification success. Added native canonical upload attempts, private bearer reservation transport with redirect rejection, certified-reservation recovery responses, exact path/token/byte validation before storage, no-overwrite bank-bucket uploads, current authorized cheque history/custody-kind gates and own-source finalization with certified evidence readback. Focused transport checks use the actual custody choice mapping and verify deposit denial after receipt, valid clearance/return stages, forged-path denial, exact bytes, stable requests and identity rejection. Native TypeScript, lint and whitespace checks passed. Upload transport remains unwired; picker/recovery/withdrawal UI and live server credential/Storage/device acceptance remain required. The current local native upload API production build is still running.

Separately observed GitHub CI run 37708597017 complete successfully for released commit 1f4985a: both web validation/regression/build and mobile locked-install/TypeScript/lint/iOS-Android-web export jobs passed. This verifies the CI configuration on GitHub, not full signed-in product/device/provider acceptance. Full goal remains active.


### Native bank-document upload integration — 8 October 2026

Connected the mobile cheque review to the private bank-document picker, with choices derived from the verified custody stage. Requires explicit selection and upload confirmation; preserves the reservation for certification after uncertain storage and never overwrites existing files. Reads and validates PDF/JPEG/PNG signatures and byte lengths, removes picker cache copies after validation or rejection, and verifies certification independently of bank approval. Unresolved retained cheque decisions suppress new upload controls. Added focused native picker/retry/cache-cleanup verification and registered transport/control/API checks in the finance regression group. Native and root TypeScript, native lint, focused API/transport/control/decision checks and iOS/Android/web export passed. Live read-only Supabase metadata confirms RPC signatures, private bucket, 8 MB/MIME limits and evidence-table RLS. Full regression handle 28287 and production build handle 72985 remain running; compiled and TypeScript stages have passed. No live bank document uploaded, no bank decision recorded and no deployment made for this increment. Native reservation recovery after app restart, live authenticated cross-role/device acceptance and remaining production plan work are still open.

Production build handle 72985 subsequently completed with exit 0. The native export completed with exit 0 at /private/tmp/openhouse-cheque-upload-mobile. Full regression handle 28287 remains live; no release claim is made before its terminal result.


### Native cheque reservation recovery — 8 October 2026

Added paged original-uploader reservation history bound to fresh verified finance membership, organization and complete bank custody history. Narrow metadata includes reserved/uploaded/withdrawn/expired status and whether evidence is already frozen in a bank decision; paths and signed tokens are excluded. Connected recovery certification and explicit audited withdrawal, with no withdrawal of used bank evidence and no edits after terminal custody states. Existing retained uncertain cheque decisions suppress document controls until recovered. Focused reader, screen, certification, withdrawal and decision tests pass. Prior full suite completed 56/56 groups, production build and all-platform exports passed for the upload increment. Final recovery TypeScript/lint handles 57725/60832, finance regression 56900 and all-platform export 98994 are in progress; their results are not assumed. Actual authenticated finance/device acceptance, secure application origin/server credentials and remaining full production milestones remain open.

Final recovery checks completed successfully: mobile TypeScript and lint, the complete native-finance group including new recovery checks, and iOS/Android/web export at /private/tmp/openhouse-cheque-recovery-mobile. The preceding full suite completed 56/56 groups; root API build passed. Prepared for commit and the previously authorized main/Vercel release. No signed native app or live bank workflow acceptance is claimed.


### Correct production release verified — 8 October 2026

Commit 72ddd39567f6b9deb397cb1b137ba55ea8e7846a was pushed successfully to main. Vercel deployment dpl_3RaCKtnXFrg9zsSuJH72StNcpzD3 is READY on the existing openhouse-realty-i43c project with www.openhousejamaica.com/apex aliases. Independent HTTPS probes returned 200 for homepage, /demo/explore and /demo/realtors with brand content; native cheque-evidence GET returned 405 and unsigned JSON POST returned 401 without data operations. GitHub run 37709990829 mobile job passed; validate job remains live in its regression step. Physical native launch acceptance and authenticated bank flows remain unverified.

### Native cheque receipt submission layer

Added canonical explicit-approved receipt request using shared cheque validation and finance/admin authority. Calls the existing custody RPC with a stable request ID, checks the exact retained receive audit and immutable property/payer/bank/reference/JMD minor amount against complete history, then rechecks membership. Permits verification of a successful original receipt after later custody progression without creating a new request; separates custody from ledger credit. Focused tests cover amount boundary, normalization, approval, authority denial, invalid acknowledgment/audit/source identity, changed access and uncertainty. Native TypeScript and lint passed. Registered regression command. This module is not yet wired to a native intake form or encrypted new-receipt recovery; it is uncommitted and not included in the live release above.


### Native new-receipt request recovery

Added account-isolated recovery for approved new cheque receipts before a cheque ID exists. Uses the existing device-store interface under a separate receipt-intake namespace. Serializes operations, preserves identical retries, rejects replacement or clearing of different unresolved requests, validates the canonical receipt with the actual shared validator, and verifies persistence/deletion readback. Focused tests prove owner isolation, conflicting concurrent requests, malformed/tampered payload denial and storage failures; existing cheque decision/recovery and receipt transport tests also pass. Native TypeScript and lint passed. The receipt form and binding to encrypted device storage are next; no live receipt was created and this uncommitted increment is not part of production 72ddd39. Full production scope remains active.


### Native cheque intake connected — 8 October 2026

Added finance-cheque-new route with verified admin/finance access checked before and after encrypted recovery reads. Receipt form requires a property from the approved finance dimension picker, payer/bank/reference, exact decimal JMD amount, reason and explicit approval before immutable review. Confirmed requests persist through the existing native SecureStore adapter before custody RPC, retain the same payload after uncertainty/reopening, and clear only after verified receipt or definitive known rejection. Browser mutation is excluded; failures in authority or encrypted recovery suppress the editor. Connected register entry and branded page title. Focused tests passed for exact amounts, property selection, approval/review, persist-before-send, duplicate/stale guards, sticky uncertain retries, unmount/reopen, browser exclusion, loader identity/access/error gates and custody handoff. Native TypeScript/lint, complete native finance regression group and cheque recovery group passed. iOS/Android/web export handle 25186 remains live; web/iOS bundles built, terminal result pending. No real receipt created; native device, signed release and live role acceptance remain outstanding. Production 72ddd39 CI now passed both jobs.

Receipt intake all-platform export completed with exit 0 at /private/tmp/openhouse-receipt-intake-mobile. All checks for this increment are terminal and passing. Preparing the native receipt workflow for the authorized main update; production readiness is still unproven against the complete development plan.


### Native navigation consistency and release checkpoint

Corrected five stale Your account links in finance accounts, journals, invoices, cheque register and contractor work offers to /account after the workspace moved out of the home route. Native TypeScript/lint and diff checks passed; this reversible route-target-only correction does not require new implementation-mirroring tests. Vercel deployment dpl_9ZysYET5sagYJU2o2NvJbNb9rvDM for main 871b91567d228fdebf9a1817ef36708afb63940f is READY on openhouse-realty-i43c with public-domain aliases. CI run 37710655951 is monitored separately. No signed native binary distributed. Code inspection confirms the existing web post_cleared_cheque ledger engine is not yet represented by a native posting reader/approval flow. Next implement native clearance/source/journal/reversal verification and controlled accounting approval, preserving the full plan and outstanding live/provider/device/lifecycle gates.


### Native cheque accounting verification foundation

Added a finance-scoped cheque posting reader tied to complete custody history, the retained clearance event and independently verified frozen bank evidence. Verifies exact JMD total, two distinct debit/credit allocations, property/unit scope, journal actor/request/reason/memo and immutable posting metadata. Returned posted cheques require a verified reversal; reversal journal metadata and inverse amount/account/property allocations must match, including linked original/reversal journals. Focused tests pass for scope, maximum amount, source/line mismatches, returned missing reversal, valid inverse reversal and changed authority. Native TypeScript/lint handles 73197/29662 are live; results pending. Reader is not yet wired to the accounting screen or approval command. No ledger posting made and no database schema changed. Full production milestones and real-device/authenticated acceptance remain open.

Cheque posting reader TypeScript and lint checks both completed successfully. Live read-only metadata confirms cheque_ledger_postings RLS enabled, anonymous SELECT denied and authenticated SELECT available under policies. This is infrastructure evidence, not authenticated workflow acceptance.


### Native cheque accounting view connected

Added accounting section to verified cheque detail, using the scoped posting reader and current parent revision. Shows verified original and reversal journal links, retained reason/Jamaica timestamp and explicit distinction from resident allocation/bank reconciliation. Missing posting, stale revision, unavailable authority/data and loading states are handled without presenting unverified links. Focused reader/detail/accounting-view tests pass; native TypeScript/lint passed. Full finance regression handle 5794 and all-platform export 65385 are live. Main 871b915 production release is READY and both CI jobs in run 37710655951 passed. New accounting view/reader and navigation corrections are uncommitted and not yet deployed. Asked which Apple Developer team should own the iPhone app, a missing distribution prerequisite; no dependent signing setup will be inferred without that input. Controlled native posting approval, device/live acceptance and complete production plan remain open.

Accounting view final checks: full native-finance group exit 0; all-platform export exit 0 at /private/tmp/openhouse-cheque-accounting-mobile. Both are terminal. No accounting mutation or signed native release performed. Continue with controlled native posting approval and durable request recovery while Apple team ownership input is pending.


### Native cheque ledger submission and retry recovery

Added canonical explicit-approved cheque posting command using the existing shared validator and post_cleared_cheque RPC. Requires fresh finance authority, an unposted cleared revision or an exact retained same-request posting, approved distinct accounts with an asset debit, and certified clearance source. Confirms returned journal against the verified posting reader and actor/request/version/account/reason bindings, then rechecks membership. Supports same-request replay after a subsequent bank return while preserving its verified reversal. Added account-and-cheque-isolated request recovery using the existing device-store interface, separate posting namespace, serialized conflict protection, canonical tamper checks and persistence/deletion readback. Focused command and recovery tests passed; native TypeScript/lint passed. Read-only live metadata confirms the RPC signature and anonymous execute denial. No live ledger entry made. Modules are not yet wired to encrypted device storage/approval UI and are uncommitted. Continue with controlled native posting approval, while full production/device/provider/lifecycle gates remain open.

### Native cheque accounting approval controls

Connected verified cleared-cheque accounting history to explicit debit/credit account selection, approval, reviewed reason and submission. The command is retained through the existing encrypted native device store before RPC; unresolved outcomes and restored requests preserve the exact approved payload. Recovery cleanup requires a verified retained receipt. Controls suppress browser submission, duplicate/stale calls and post-unmount initiation. Verified original/reversal journal links remain available independently of posting controls. Focused control tests cover persist-before-submit, sticky unknown retry, reopening and unmount; accounting display tests cover eligibility and native-only recovery. No real financial posting was created during verification. Physical-device, multi-actor database and launch acceptance remain required.

### Lease signing request boundary

Added canonical immutable staff signing intent requiring current draft version, application/draft/request references and explicit signing approval. Unknown fields reject client authority, parties, provider, signed document and tenancy status. Missing provider configuration raises a dedicated unavailable condition rather than simulated execution. Focused tests use the actual shared UUID validator and verify approval bounds/spoof rejection; root TypeScript passed. The validator is not yet connected to a persisted request API or provider adapter. Provider selection, callback verification, request persistence/status UI and tenancy activation remain open. Production deployment dpl_XHAWeDFcssGjiVWE8NPZqfMUVh2S for a9eecca verified READY on the approved project's public aliases; CI was still running when checked.

### Persisted lease signing intent migration and rollback verification

Created migration 20261008011608_lease_signing_intent using Supabase CLI. Defines immutable organization-scoped signing intents with explicit awaiting_provider state, independent verified staff authority, membership/application locks, current approved draft/reservation/contact/co-signer checks and canonical same-request replay. Direct writes and anonymous execution are revoked; RLS restricts reads to independent organization staff. Successful rollback-only database tests verify pending state, replay, changed payload, stale revision, approval requirement, direct-write denial and applicant isolation. Initial connector request returned invalid/expired requestState; fresh inspection confirmed no table/fixture users remained, and the same rollback test succeeded on retry. Migration is not applied; staff API/UI and broader isolation/concurrency tests are next. No legal execution or tenancy access is granted by this intent record.

### Staff lease-signing intent API

Added POST /api/staff/lease-signing with same-origin/JSON/3000-byte limits, verified organization staff access, strict immutable signing-intent validation and explicit RPC argument mapping. Confirms exact draft/version and valid UUID acknowledgement in awaiting_provider state only; no signed or activated result is accepted. Known authorization/validation/conflict versus uncertain errors are private/no-store and do not disclose database details. Actual route/shared-validator tests and full lease-preparation regression group passed; root TypeScript passed. Root production build session 94195 is live, with output in /private/tmp/openhouse-signing-intent-build.log. Migration still unapplied; form/status view, broader DB isolation tests, signed provider and tenancy activation remain open. Asked the client which electronic signing provider/account to use; no answer yet.

### Staff signing request form and status

Added explicit signing-approval form to current prepared/approved staff lease drafts. Stable in-memory request is preserved after network/malformed acknowledgement uncertainty; duplicate/completion guards, locked approval fields and same-request retries are covered by focused control tests. Staff page reads bounded application/organization/draft-scoped request status; recorded requests suppress new form, missing/read-error status fails closed, closed/unapproved drafts suppress controls. Request status explicitly states awaiting provider and no executed lease. Focused form/page tests and root TypeScript passed. Earlier API production build session 94195 exited 0; it predates these UI changes and does not validate this new graph. New UI production build is next; migration remains unapplied and provider/device/live lifecycle acceptance remain open.

### Signing intent live schema checkpoint

Expanded rollback fixtures verify foreign organization read/write denial, unverified/revoked staff refusal including replay, and immutable update/delete denial even for the table owner. Tests passed after a transient expired connector request. Updated UI production build session 49916 exited 0. Applied additive lease_signing_intent migration successfully to the intended Open House project; aligned local migration filename to authoritative recorded version 20261008051447. Live metadata confirms RLS, anonymous execute denial and authenticated/service direct insert denial. No signing request, signed lease or tenancy was created outside rolled-back fixtures. Staff API/UI still local pending commit/deployment; provider selection and full lifecycle/live acceptance remain outstanding.

Post-migration security advisor reported no finding on rental_lease_signing_requests and no WARNING/ERROR entries. Existing 15 INFO rls_enabled_no_policy findings concern other private/legacy tables; no access policy was broadened in response. Reference: https://supabase.com/docs/guides/database/database-linter?lint=0008_rls_enabled_no_policy

### Signing release full regression gate

Final diff checks passed and release notes prepared in docs/RELEASE-2026-10-08-SIGNING-INTENT.md. Prior main a9eecca CI run 37711960989 completed success. Full local npm test is live as session 50879, output /private/tmp/openhouse-signing-full-regression.log; observed groups through lease review passed, remaining groups/terminal result pending. Do not rerun while handle remains live. Commit/push remains pending this gate; no new deployment claimed. No signing provider response received yet.

Full signing release regression session 50879 completed exit 0: 56/56 verification groups passed, including native operations/finance. Local TypeScript and new staff UI production build previously passed. Release gate satisfied for committing this implementation; authenticated client walkthrough and external signing/activation work remain outstanding.

### Signing release and withdrawal foundation

Main 3f0dff2897dfc787c644fe89e78c78cbca8c7ae1 deployment dpl_CTszNqQGw1fkHBGf79E3yicPhgoJ verified READY on the correct openhouse-realty-i43c project and public aliases. Added unapplied lease_signing_withdrawal migration with separate immutable audit row, current independent staff authority/membership/application locks, pending-state gate, explicit reason/approval, same-request replay and duplicate conflict. Original signing approval is preserved. Rollback fixture tests passed for exact/changed/duplicate withdrawal retries and retained original approval, alongside signing-intent authorization tests. Initial expired connector state was revalidated with absence of withdrawal table and retry succeeded. Withdrawal-specific role/immutability tests, HTTP/UI status integration and provider-dispatch exclusion remain next; do not apply this migration until its full path is verified. No production intent withdrawn and no legal lease activated.

### Signing withdrawal HTTP boundary

Added strict signing-withdrawal validator and POST /api/staff/lease-signing/withdraw using existing same-origin/bounded-body/verified staff gates and explicit withdrawal RPC. Requires explanation and approval; rejects client authority fields; confirms exact signing ID, UUID receipt and withdrawn state. Focused actual route/validator tests passed for approval, malformed/forged input, identity/origin/body, known errors and uncertain acknowledgement. Root TypeScript passed. Expanded rollback fixtures with withdrawal-specific foreign/applicant/revoked access and owner immutability assertions; these new assertions have not yet been executed. Migration remains unapplied, status/form integration and full release checks remain next.

### Withdrawal form and database isolation acceptance

Added explicit explained withdrawal form with stable-request uncertainty retries and exact signing/withdrawn receipt binding; focused UI tests and initial root TypeScript passed. Expanded rollback DB tests passed for withdrawal foreign/applicant/revoked read/write/replay exclusion and immutable owner update/delete, following expired connector state cleanup verification and retry. Connected staff page to bounded organization/signing-ID withdrawal lookup, retained withdrawn reason and pending withdrawal controls; request or withdrawal read errors suppress both new signing and withdrawal submissions. Final page integration checks are session 78036, result pending when recorded. Migration remains unapplied; page-specific withdrawn/error tests and production build are next. No live signing request was withdrawn.

### Withdrawal acceptance and applied schema

Dedicated staff page tests verify retained withdrawn reason, absence of signing/withdrawal actions on withdrawn records, exact organization/signing scope and suppression on withdrawal read errors. Lease preparation/summary regression groups passed, and production build session 32026 exited 0. Applied withdrawal migration successfully, aligned local filename with database history version 20261008061027. Live metadata confirms RLS and anonymous execution/direct authenticated insert denial; security advisor has no finding on withdrawal table. UI/API release remains to be pushed and deployment confirmed. No production request withdrawn; provider dispatch must exclude withdrawal audit records when that adapter is implemented. Provider/legal execution and tenancy lifecycle remain outstanding.

### Signing request currentness presentation

Release c76147a production deployment dpl_DYHHRFQusPyK65ZcHrr9XaeWmaha observed QUEUED; CI run 37736219682 in progress. Neither is restarted or claimed ready. Corrected staff page presentation of retained pending requests against superseded/voided drafts, withdrawn applications or different approval revisions: shows outdated/do-not-dispatch warning while preserving withdrawal cleanup. Query now reads immutable draft application_version. Focused page tests cover each stale condition and retain pending versus withdrawn/error behavior; draft page regression also passed. TypeScript session 72638 result checked separately; new production build is started at /private/tmp/openhouse-signing-stale-build.log. These presentation checks are not a provider dispatch implementation. Full production lifecycle and external provider inputs remain outstanding.

Signing stale-warning build session 23155 completed exit 0. Withdrawal release c76147a deployment dpl_DYHHRFQusPyK65ZcHrr9XaeWmaha verified READY on approved public aliases; CI run 37736219682 still in progress. Public HTTPS smoke first failed in sandbox DNS; retried read-only via authorized network escalation as session 42429. Outdated request warning remains local pending commit. Move-in preparation is the next independent implementation track while provider selection remains unanswered.
