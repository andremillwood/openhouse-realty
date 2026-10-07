# OpenHouse Realty

A personalized real-estate marketplace and property operating system for Jamaica.

## Product thesis

OpenHouse connects public property discovery, seller services, leasing, resident experience, property operations, contractors, finance, and owner reporting around a shared property model.

The marketplace has two complementary discovery modes:

- **Search** — show users what exists.
- **For You** — show users what deserves their attention using explicit requirements, preferences, approved inferred preferences, intent, and appropriate behavioral signals.

## Stack

- Next.js 16.3 / React 19
- TypeScript
- Supabase: Postgres, Auth, Storage, Realtime where useful
- Resend: transactional email
- Vercel: preview and production deployments
- GitHub: source control and pull-request workflow

## Local setup

1. Use Node 22 or newer.
2. Copy `.env.example` to `.env.local`.
3. Add the Supabase project URL and publishable key when the project is provisioned.
4. Install dependencies with `npm install`.
5. Run `npm run dev`.

See [service setup](docs/SERVICE-SETUP.md) for the linked Vercel project, Supabase migration workflow, and Resend configuration.

## Database

The initial secure schema is in:

`supabase/migrations/20261006143920_marketplace_foundation.sql`

All exposed tables must use Row Level Security. Do not add client-side-only authorization.

## Current production vertical

The first implementation proves:

Marketplace → For You → explainable match → Save / Not for me → preference learning → property detail → viewing → prospect/application.

Seller, resident, contractor, management, finance, and owner domains extend the same property/person model rather than becoming separate applications.

## Architecture

See:

- `docs/ARCHITECTURE.md`
- `docs/PRODUCT-PRINCIPLES.md`
- `docs/EVENTS.md`

## Security

Never commit credentials, private keys, resident records, application documents, or production data.

The Supabase secret/service key must remain server-only. Any variable prefixed with `NEXT_PUBLIC_` is shipped to the browser.

## Client demo

Open `/demo` to choose one of nine fictional profiles and navigate the role-based workspace without a password. Use **Start guided walkthrough**, **Explore as**, and **Reset demo** to explore cross-role workflows. Actions are session-local simulations and do not change production records or move money.

See [demo guide](docs/DEMO-GUIDE.md) for the presentation sequence and [delivery status](docs/DELIVERY-STATUS.md) for the production backlog. Run `npm run test:demo` to verify workflow transitions and session restoration.

## Production development

The dependency-ordered execution plan is in `docs/PRODUCTION-DEVELOPMENT-PLAN.md`; evidence and remaining launch work are in `docs/DELIVERY-STATUS.md`.

Public `/`, `/listings` and `/realtors` read approved published Supabase data. Illustrative experiences are available under `/demo/marketplace`, `/demo/listings` and `/demo/realtors`. Verified prospects can save properties and submit stored enquiries; catalog staff and enquiry staff require database-assigned organization membership. Background email activation still requires protected worker credentials and scheduling.

Focused checks: `npm run test:catalog`, `npm run test:discovery`, `npm run test:notifications`, and `npm run test:demo`. Transactional database enquiry checks live in `scripts/sql/verify-enquiries.sql` and roll back their fixtures.
