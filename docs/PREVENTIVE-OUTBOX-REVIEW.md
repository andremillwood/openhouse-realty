# Preventive notification outbox change — pending approval

The proposed migration is `docs/proposals/preventive_outbox_bridge.sql`. It has not been applied and is deliberately outside the runnable migration directory. Promote it to a fresh timestamped migration only after approval and cross-workflow verification. Supabase migration history returned no matching record after automatic approval review rejected the request.

## Proposed behavior

- Add a preventive-event reference and enforce one source entity per outbox record.
- Queue one service-prepared notice per preventive event, binding its organization and workspace path from the database.
- Recheck current-event eligibility during claim and before sending; supersede stale notices.
- Preserve sender/recipient/content snapshots and the existing delivery lease/retry model.
- Add a preventive monitor family visible to organization management.

## Shared changes and risk

The migration replaces organization binding, both claim functions, the pre-send predicate and both monitor functions. Those functions also serve enquiries, applications, viewings, contractor maintenance and staff invitations. A regression could prevent delivery, claim the wrong records or misclassify monitoring across those workflows. Existing workflow branches are carried forward in the proposed source, but that is not proof of safe database behavior.

Automatic approval review rejected application because the shared rewrites create substantial cross-workflow disruption risk. No alternative execution or splitting was used to bypass that rejection. Before applying, verify all shared database workflows against the proposed migration and obtain explicit approval for the shared change.

## Completed unaffected work

The unconnected `preparePreventiveNotifications` helper validates the whole bounded batch before queueing, uses canonical private notice content, distinguishes stale-event suppression from queued notices and closes on uncertain results. Its focused checks and TypeScript passed. It does not claim or send email, and the live worker does not invoke it yet.

The existing full-platform goal remains active. Worker integration, monitor UI, broad database regression, concurrency, scheduling and live provider acceptance remain unfinished.
