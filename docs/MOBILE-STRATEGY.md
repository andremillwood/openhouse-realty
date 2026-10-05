# Native Mobile Strategy

OpenHouse will support both a web product and native iOS/Android applications.

## Technology direction

Use:
- **Next.js** for the public marketplace, seller experience, detailed management, finance, owner reporting, and administration.
- **Expo + React Native** for native iOS and Android.
- Shared backend/domain contracts over Supabase and server APIs.
- Shared TypeScript packages where doing so improves consistency without forcing web and native UI to share components.

Do not ship the mobile requirement as a WebView or merely wrap the responsive website.

## One role-aware native application first

Do not create separate apps for every stakeholder in v1.

After authentication, navigation and capabilities change according to the user's role and permissions.

### Prospect
- For You.
- Search.
- Saved.
- Property details.
- Tours and open houses.
- Notifications.
- Property guide/chat.

### Resident
Primary navigation:
- Home.
- Pay.
- Service.
- Access.
- More.

Mobile-specific capabilities:
- Camera-first maintenance reporting.
- Push updates.
- Visitor creation.
- Document access.
- Receipts.
- Biometric re-entry where appropriate.

### Contractor / workman
Primary navigation:
- Today.
- Jobs.
- Check in.
- Invoices.

Mobile-specific capabilities:
- Work-order context.
- Geared for one-handed field use.
- Before/after photos.
- Parts/labour capture.
- Check-in/out.
- Resident confirmation.
- Offline-tolerant drafts where practical.

### Security guard
Primary navigation:
- Gate.
- Expected.
- Onsite.
- Incidents.

Mobile-specific capabilities:
- Fast visitor lookup.
- Workman/contractor sign-in/out.
- Scan/lookup access credentials where supported.
- Incident photo/evidence capture.
- Emergency contacts.

### Property manager
Primary navigation:
- Today.
- Attention.
- Property.
- Search.

Mobile-specific capabilities:
- Approval/decision actions.
- Incident alerts.
- Work-order reassignment.
- Property-wide search.
- Push notifications for material exceptions.

## Native requirements from the start

The backend must support:
- device registrations,
- push notification tokens,
- role-aware sessions,
- deep links,
- file/photo uploads,
- mobile audit events,
- notification preferences,
- secure local session handling.

## Monorepo target

Once native development begins:

```
apps/
  web/
  mobile/
packages/
  domain/
  api-contracts/
  validation/
  config/
supabase/
  migrations/
```

The current repository can remain web-rooted during the marketplace foundation. Move to the monorepo before native implementation begins rather than prematurely reorganizing an empty app.
