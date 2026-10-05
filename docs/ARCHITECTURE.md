# OpenHouse Architecture

## Product boundary

OpenHouse is not a CRM with property features attached. It is a shared real-estate system with several experiences over the same domain model:

1. Public marketplace: buy, rent, sell, agents, property management.
2. Personalized discovery: Search, For You, preferences, saves, hides, recommendations.
3. Prospect and applicant journey.
4. Resident experience.
5. Contractor and field-service experience.
6. Property-management operations.
7. Owner reporting.

## Production stack

- Next.js 16 App Router on Vercel.
- TypeScript.
- Supabase Postgres, Auth, Storage, Realtime where useful.
- Resend for transactional email.
- GitHub for source control and review.
- Third-party providers are adapters behind domain services, not embedded directly into UI components.

## Architectural rules

### 1. Property and person are first-class graphs

The property graph connects organization → property → unit → listing → lease → assets → service history.

The person graph connects identity → household → prospect/applicant/resident role → preferences → interactions → transactions.

Personalization lives where property and person data meet.

### 2. Search and For You are different products

Search is exhaustive and user-directed.

For You is selective, explainable, and driven by:
- hard requirements,
- stated preferences,
- approved inferred preferences,
- current intent,
- behavioral signals.

### 3. Domain events connect workflows

UI components do not send email or mutate unrelated domains directly.

Examples:
- listing.saved
- listing.hidden
- preference.updated
- viewing.requested
- application.submitted
- unit.market_ready
- service.reported
- work_order.completed
- payment.received

Handlers can then update recommendations, create tasks, send notifications, or update reporting.

### 4. Authorization is database-enforced

RLS is mandatory on exposed Supabase tables.

Client-side role checks are presentation only, never authorization.

### 5. Human language in the UI

Internal architecture can use precise domain terminology. User-facing language should describe what the person is trying to accomplish.

### 6. Protected characteristics are not recommendation features

Housing personalization must not rank, exclude, or steer inventory using protected or sensitive personal characteristics. Recommendations are based on property criteria, explicit user preferences, and appropriate interaction signals.
