# Web launch acceptance

Priority confirmed October 8, 2026: web marketing, prospect/buyer, team/admin/realtor and property management for immediate business use. Mobile remains a demo milestone. This matrix records observed gaps, not a completion percentage.

| Journey | Current evidence | Required acceptance |
| --- | --- | --- |
| Marketing navigation → service → contact | Home, Sell, Realtors and Open Houses routes exist. Added `/services`; connected header/home management CTA. | Render on desktop/mobile, test every CTA, client-approved copy and imagery. |
| Company information and contact | Added `/about` and `/contact` using supplied brand language and enquiry email; shared footer links company/services/team/contact. | Build/render/link acceptance, approved expanded company facts, public phone/address/hours if applicable. |
| Privacy and terms | No dedicated Privacy or Terms routes found in current app tree. | Business/legal-approved policy text and accessible links from relevant forms/footer. Do not invent legal commitments. |
| Search/map → details → saved/enquiry/viewing | Existing listings/detail/account routes and regression groups. | Published real inventory, map/list synchronization, signed-in persistence, submitted record visible to staff, email observed, unavailable/conflicting slots denied. |
| Realtor matching → prospect handoff | Published-profile queries and preference implementation. | Approved profiles/coverage, consented matching with reasons, working handoff and live signed-in acceptance. |
| Team/admin catalog and prospect work | Staff enquiry, profile history, viewings and open-house routes exist. | Approved staff identities, organization isolation, publish/pause and follow-up verified on deployment. |
| Management daily operations | Property, maintenance, contractor, preventive and finance functionality implemented. | Client walkthrough from property/unit to assigned work and completion; owner permissions; actual configured storage/notifications. |
| Lease → move-in → resident | Preparation work in flight; provider integrations remain dependencies. | Approved legal/signing/payment inputs, verified events, activation/access/household lifecycle. Preparation alone is insufficient. |
| Production operation | Approved Vercel project established; prior deployment evidence. | Latest release readiness, Auth callbacks/email, worker credentials, delivery failures, restore exercise and business acceptance. |

Latest observed validation: pre-services change regression run session 9291 exited 0, 57/57 groups. Move-in build session 20745 exited 0; rollback access tests passed. Services page needs its own build and rendered acceptance; those are not established by the earlier suite. Browser preview tool previously crashed; no device/browser visual acceptance is claimed.

Next: verify services/company/contact release and rendered paths; inspect prospect/team/management paths with real signed-in acceptance and record concrete failures. Approved policies/provider onboarding are tracked external inputs rather than simulated completion.
