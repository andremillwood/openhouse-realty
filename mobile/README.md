# Open House Realty native app

Status: active implementation; not ready for client distribution or store submission.

This isolated Expo SDK 57 / React Native workspace shares the existing Supabase project and actual identity model. The web app remains at the repository root. Native dependencies, TypeScript and builds run from this directory.

## Development

Run `npm ci`, configure `.env.local` from `.env.example`, then use `npm run start`. Use only the Supabase publishable key. Supabase server secrets, Resend credentials, worker secrets and provider signing keys must never enter a native bundle. The canonical web origin must be approved before external links are enabled.

Expo Router navigation, the supplied blue logo, secure persisted sign-in, foreground refresh and fresh verified-identity checks are implemented. Live public search, published-only pagination/details and approximate-area map discovery are implemented. Verified saved-property status, save/remove controls and private paginated shortlist are implemented. Enquiry/viewing and role-specific journeys remain next. No native account selection may grant staff, contractor, security or resident authority: live database permissions determine access. Native resident access awaits the signed-lease/tenancy lifecycle.

## Remaining native acceptance

- Secure session persistence, foreground refresh, logout cleanup and stale identity suppression.
- Shared authorized prospect, manager, contractor, security and resident record journeys.
- Actual device acceptance of property list/map/detail and verified private saved properties.
- Camera/document capture with the existing private upload/verification workflow.
- Validated deep links, push consent/device registration and audited delivery.
- Native TypeScript/lint/export checks, device permission and cross-role isolation checks.
- iOS/Android development builds, actual device acceptance, approved application identifiers and store accounts.

The entry screen uses the approved supplied blue logo. Generated launcher and splash assets remain placeholders to replace before distribution. No EAS project or application identifier has been provisioned yet.

The native map renders only approved approximate listing coordinates and never requests device location. Map/list pages share the same bounded result page; markers open property cards. Android distributed binaries require GOOGLE_MAPS_ANDROID_API_KEY in the EAS build environment, enabled for the approved application identifier/certificate. iOS uses Apple Maps. Map tile/device acceptance remains open. The web preview provides approximate-area links.

The two apps retain independent dependency installations. Metro watches the shared pure discovery helpers in ../lib/discovery; native catalog filters use the same sanitizer and page rules as the web product.
