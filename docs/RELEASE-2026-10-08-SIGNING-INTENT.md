# Lease signing intent release

The staff lease preparation page can record explicit approval to request legal signing for a current prepared draft. It shows an existing request as awaiting provider configuration, and withholds new submissions when request status cannot be verified. This release does not execute a legal lease or activate resident access.

The request endpoint enforces verified independent organization staff, bounded same-origin JSON, canonical approved intent and exact pending receipt binding. The database independently rechecks approval, reservation, contact and co-signer snapshots under membership/application locks. Request history is immutable and repeated identical requests return the same receipt.

Applied Supabase migration: `20261008051447_lease_signing_intent.sql`. Local production build, TypeScript, lease preparation/summary regression groups and rollback-only database fixtures passed. Fixtures covered applicant/foreign organization isolation, revoked/unverified staff, exact replay, approval/revision checks and owner-level immutability. No legal lease, tenancy, payment or real email was created in acceptance testing.

Release gate: full local regression suite and GitHub/Vercel release results are tracked in delivery status. Authenticated production staff walkthrough and client visual acceptance remain outstanding. Provider selection, legal execution verification, cancellation/status lifecycle and tenancy activation remain subsequent work.
