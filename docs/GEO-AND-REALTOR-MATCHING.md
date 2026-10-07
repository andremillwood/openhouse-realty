# Location and realtor matching

## Implemented experience

- `/listings`: buy/rent, area, text, and session save filters; list/map/split views; price markers; selected pin summary linking to a property detail.
- `/listings/[id]`: property summary, viewing enquiry email draft, approximate neighborhood map, and a realtor matching entry point.
- `/realtors`: clearly labelled example profiles, five-question working-style matching, ranked suggestions, reason explanations, editable answers, and introduction email drafts.

The app uses demonstration inventory and example realtor profiles from `lib/discovery/data.ts`. No real realtor identity, availability, qualification, or psychological assessment is implied. Actual roster and approved listing information must replace the demo records before launch. No production demo inventory has been inserted into Supabase.

## Geographic data

Public map points are approximate neighborhood locations. Exact private coordinates must not be put into the public listings table. Leaflet loads OpenStreetMap tiles on demand with attribution; there is no location permission request, background tracking, geocoding, or invented commute estimate. A tile failure notice leaves the list available. Choose an appropriate hosted tile provider before high-volume launch and retain attribution.

Schema migration `20261006151241_geo_realtor_matching.sql` adds bounded, paired approximate coordinates and a location label to listings. It also adds realtor profile and matching preference tables with RLS and explicit grants. Only published realtor profiles are publicly readable; clients cannot publish profiles. Saved matching preferences are scoped to their authenticated owner. The current questionnaire does not persist answers or invoke this table until a consented save/auth flow is implemented.

## Matching model

The prospect explicitly chooses their intent, area, communication style, guidance preference, and decision pace. Candidates must first serve the selected area and support the selected journey. Each of the three style agreements contributes two points; area and intent contribute one each (eight total). Results are sorted deterministically with name as a tie-breaker. These points describe preference agreement, not a probability of success. The UI shows both reasons and unmatched points, allows every realtor to be considered, and does not use sensitive demographic attributes or behavioral inference.

Only the prospect's deliberate click on an introduction link creates a draft containing their answers in their own email client. Nothing is sent automatically. A future server submission should validate inputs, enforce abuse prevention, store an enquiry, and invoke the server-only Resend helper with a stable idempotency key.

## Follow-on product work

Actual realtor roster and approved service styles; real property photography and verified locations; live Supabase inventory adapters; authentication and explicit opt-in preference persistence; enquiries and viewing scheduling; resident and staff dashboards with role-aware access. These are separate from the working discovery and matching UI delivered here.
