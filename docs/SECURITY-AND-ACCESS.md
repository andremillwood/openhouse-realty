# Security and Access Operations

## Guard workspace

The security experience is operational, not a generic dashboard.

A guard needs to answer quickly:
- Who is expected?
- Who is onsite now?
- Why are they here?
- Where are they going?
- Who authorized them?
- Have they left?
- Is there an active incident?

## Core records

- guard_profile
- guard_shift
- visitor
- visitor_pass
- access_event
- contractor_visit
- worker_presence
- delivery
- incident

## Workmen onsite

A workman/contractor visit connects:
- person,
- vendor/company,
- work order,
- destination/unit,
- authorization,
- expected window,
- ID/verification state,
- checked_in_at,
- checked_out_at,
- guard/staff member who processed entry.

Management can query **currently onsite** without reading a paper book.

## Incident record

Incident:
- category,
- severity,
- property/location,
- reported_by,
- people involved,
- description,
- media/evidence,
- timestamps,
- actions taken,
- escalation,
- resolved_at.

Sensitive incident information requires tighter role policies than ordinary visitor records.

## Privacy rule

Security staff receive the minimum resident information required to safely authorize access. They do not receive unrestricted access to resident, application, or financial records.
