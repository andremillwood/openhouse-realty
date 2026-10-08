# Web launch acceptance

Priority confirmed October 8, 2026: web marketing, prospect/buyer, team/admin/realtor and property management for immediate business use. Mobile remains a demo milestone. This matrix records observed gaps, not a completion percentage.

| Journey | Current evidence | Required acceptance |
| --- | --- | --- |
| Marketing navigation → service → contact | Home, Sell, Realtors and Open Houses routes exist. Added `/services`; connected header/home management CTA. | Render on desktop/mobile, test every CTA, client-approved copy and imagery. |
| Company information and contact | Added `/about` and `/contact` using supplied brand language and enquiry email; shared footer links company/services/team/contact. | Build/render/link acceptance, approved expanded company facts, public phone/address/hours if applicable. |
| Privacy and terms | No dedicated Privacy or Terms routes found in current app tree. | Business/legal-approved policy text and accessible links from relevant forms/footer. Do not invent legal commitments. |
| Search/map → details → saved/enquiry/viewing | Existing listings/detail/account routes and regression groups. | Published real inventory, map/list synchronization, signed-in persistence, submitted record visible to staff, email observed, unavailable/conflicting slots denied. |
| Realtor matching → prospect handoff | Published-profile queries and preference implementation. | Approved profiles/coverage, consented matching with reasons, working handoff and live signed-in acceptance. |
| Team/admin catalog and prospect work | Staff enquiry, profile history, viewings and open-house routes exist. Protected team workspace/grouped role navigation and operational return links implemented locally; access/navigation tests pass. | Approved staff identities, organization isolation, publish/pause and follow-up verified on deployment. |
| Management daily operations | Property, maintenance, contractor, preventive and finance functionality implemented. | Client walkthrough from property/unit to assigned work and completion; owner permissions; actual configured storage/notifications. |
| Lease → move-in → resident | Preparation work in flight; provider integrations remain dependencies. | Approved legal/signing/payment inputs, verified events, activation/access/household lifecycle. Preparation alone is insufficient. |
| Production operation | Approved Vercel project established; prior deployment evidence. | Latest release readiness, Auth callbacks/email, worker credentials, delivery failures, restore exercise and business acceptance. |

Latest observed validation: marketing release 318462d deployed READY on approved aliases; Services/About/Contact public HTTPS checks returned 200 with contact/footer present. Web authentication release 3463a48 deployed READY; focused account, enquiry, viewing, callback and catalog checks plus TypeScript/build passed before release. Actual delivered-email/authenticated-browser acceptance remains open. Earlier regression session 9291 passed 57/57 groups. Team workspace is local pending final build/release. Move-in schema remains unapplied. Browser preview tool previously crashed; no browser/device visual acceptance is claimed.

Next: verify services/company/contact release and rendered paths; inspect prospect/team/management paths with real signed-in acceptance and record concrete failures. Approved policies/provider onboarding are tracked external inputs rather than simulated completion.

## Production onboarding observation — October 8, 2026

Read-only query of the intended Supabase project zikxzkbfxgdilykyyswt returned zero published listings, zero published realtor profiles, zero verified nonanonymous staff memberships, zero managed properties and zero units. This establishes a concrete launch prerequisite: approved administrator provisioning and real catalog/management onboarding. It does not establish that no Auth users exist. Requested first administrator email and organization name; require owner-created verified account before assigning privileged access. No identities or approved business inventory were invented. Browser automation failed with sandbox kernel diagnostics; visual acceptance remains unverified.
