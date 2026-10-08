# Inputs needed to complete the production launch

Observed October 8, 2026 on the intended Open House Supabase/Vercel projects. This checklist retains the full platform scope; it is not a declaration that engineering is complete.

## Administrator and approved inventory

The database currently has no Auth account for `andremillwood@gmail.com`, no verified staff, no published listings/realtors, and no managed properties/units.

- Create or invite Andre Millwood using Supabase Authentication Users: https://supabase.com/dashboard/project/zikxzkbfxgdilykyyswt/auth/users . Accept/verify the invitation before privileged membership is assigned. Alternatively, use the web signup flow and verify its email.
- The guarded first-admin bootstrap is prepared, but cannot run until the verified identity exists. Current organization roles include admin; platform-wide superadmin requires separately defined scope and permissions, rather than relabeling an organization admin.
- Provide approved listing photography/descriptions/prices/approximate public locations, realtor bios/coverage/preferences, and private managed-property/unit inventory. Demo examples cannot establish real publication or operational acceptance.

## Server and delivery setup

Configure secrets directly in the approved project's protected production environment: https://vercel.com/andre-millwoods-projects/openhouse-realty-i43c/settings/environment-variables . Do not paste values in chat or commit them.

- `SUPABASE_SECRET_KEY`: intended project's server credential for private storage, workers and authenticated callback recording.
- `RESEND_WEBHOOK_SECRET`: provider-issued signing secret for the registered `https://www.openhousejamaica.com/api/webhooks/resend` callback.
- `CRON_SECRET` has already been provisioned as a production-only sensitive variable. Scheduling remains unconfigured/unverified.
- Confirm Supabase Auth SMTP/Site URL/callback configuration; observe real signup/recovery and business delivery to `ohrealty@flashcreate.co`.

## Business decisions for the remaining lifecycle

- Approved signing provider and legal template/retention policy.
- Approved payment provider, deposit/billing/reconciliation/refund rules and settlement evidence requirements.
- Notice periods, renewal approval, inspection/dispute and deposit-disposition rules. These cannot be guessed from demo screens.
- Approved Privacy/Terms and company facts (phone/address/hours if public).

Verified execution/payment then unlock atomic tenancy activation, household permissions, resident operations, renewal/notice/move-out and refunds. These live journeys remain unfinished; prepared drafts, reviewed summaries and move-in checklists do not grant resident authority.

## Acceptance and distribution

- Verified multi-role client walkthrough with approved records: prospect, realtor/admin, manager, owner, contractor/security and finance; then resident lifecycle once activation exists.
- Rendered desktop/mobile/PWA installation and offline/reconnect checks. Browser automation currently fails at sandbox kernel startup; HTTP checks do not replace device acceptance.
- Notification schedules, storage cleanup, monitoring and backup/restore acceptance.
- Mobile remains a polished demo milestone; native distribution/signing and extended discovery remain in the full plan.

The latest web build/test/deployment evidence is recorded in DELIVERY-STATUS.md. Passing focused tests does not satisfy the missing business workflows or inputs above.
