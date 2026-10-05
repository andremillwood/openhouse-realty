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

## Database

The initial secure schema is in:

`supabase/migrations/20261005100000_marketplace_foundation.sql`

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
