# Tenancy lifecycle implementation audit

Repository evidence inspected 8 October 2026. This is an engineering dependency audit, not legal approval or proof of live database state.

## Existing foundation

- `20261006143920_marketplace_foundation.sql` defines properties and units; listing status `leased` is catalog metadata and grants no resident access.
- `20261007041106_rental_lease_draft_preparation.sql` defines prepared/superseded/voided lease drafts, derived from application approval, reservation and approved template. Its explicit contract grants no signature or tenancy authority.
- `lib/leases/validation.ts` validates approved draft terms, dates, billing day and exact JMD deposit amounts.
- `20261007130036_shared_lease_summary_release.sql` and `20261007131430_lease_summary_review.sql` support sharing and reviewing summaries. Applicant review must not be interpreted as executing a legal lease.
- `20261008051447_lease_signing_intent.sql` and `20261008061027_lease_signing_withdrawal.sql` persist signing intent and audited withdrawal, with staff/applicant status views. Intent remains awaiting an approved provider; it is not verified execution.
- `20261008065947_move_in_preparation.sql` records immutable, versioned unit readiness, utilities and access preparation decisions. These operational records do not establish payment, signature or resident authority.
- The migration inventory still contains no verified signed-lease execution, tenancy activation, renewal, notice, move-out or deposit-disposition schema. Demo tenancy interactions are not implementation evidence.

## Required implementation sequence

1. Signing boundary: bind organization, approved current draft/version, template hash, applicant and required co-signers to an immutable signing request. Use an approved provider adapter with authenticated callbacks, replay protection, signed document hash and independently verified completion receipt. Persist failure/cancellation without issuing access. Provider selection and approved legal template remain external inputs.
2. Activation: create an audited tenancy only from verified execution, current application approval and valid unit reservation. Recheck staff membership and lock the unit/application during activation. One active tenancy per unit; same request replays the same receipt. Deposit and move-in approval must cite authoritative payment and checklist records rather than client booleans. Household access is granted from active tenancy membership, never listing status or applicant summary review.
3. Resident access: replace demonstration/baseline associations with tenancy-bound authorization; isolate household, document, statement, service and gate access by organization/unit/active membership. Test cancellation, expiry and revoked membership across every related surface.
4. Renewal and notice: versioned approved terms, signing execution and date conflict checks; retained notice actor, method, delivery evidence and effective date. Legal notice periods are business/legal configuration, not guessed constants.
5. Move-out and deposit: immutable inspection and evidence, proposed itemized deductions, independent approval and dispute history, precise amount reconciliation against held funds. Refund execution belongs to the approved payment adapter. Closure revokes access atomically and records the final receipt; never relabel an unpaid refund as settled.

## Proof required before milestone completion

Authenticated multi-actor database tests must cover cross-organization access, stale revisions, conflicting activation, duplicate callbacks/requests, cancellation and revocation. Browser/device walkthrough must cover applicant → signed lease → approved move-in → resident → renewal/notice → inspection → deposit decision → verified refund → closure. Green draft/review tests prove only the existing draft/review scope.

Next implementation target: verified execution and payment evidence adapters, then atomic tenancy activation and household authorization. Signing-provider selection and approved legal documents remain required external inputs. `lib/leases/activation-readiness.ts` assesses server-loaded evidence and denies missing execution/payment, stale approval/reservation, missing preparation and superseding blocked decisions. It is not wired to an activation endpoint and grants no authority; the eventual database transaction must independently recheck and lock every prerequisite. No simulation may advance production tenancy authority.
