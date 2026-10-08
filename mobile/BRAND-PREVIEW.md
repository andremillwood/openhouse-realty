# Open House mobile branding

Implemented 7 October 2026:

- Brand-derived navy and white roof/window app icon in `assets/openhouse-app-icon.png`, configured for iOS, Android and web.
- Native splash config uses the supplied blue Open House logo against the light brand background, with 260-point logo width. Splash stays visible until custom fonts resolve; errors release the splash as well.
- Shared navigation bars use a safe-area-aware two-row layout: a larger supplied wordmark and account shortcut above an Inter page title with an accessible back control. Titles wrap separately from the logo, avoiding competition for horizontal space.
- Home uses its own safe-area-aware brand header instead of a second navigation header.
- Sign-in and registration share a navy welcome panel, overlapping white form card and keyboard-aware, scrollable branded layout with labelled fields, password visibility controls, disabled submission states and inline feedback. Recovery and confirmation resend are available from expandable sign-in controls. Existing identity verification, duplicate submission guards and invitation return behavior remain in place.

Validation: mobile TypeScript and lint passed; Expo public config resolved the icon and splash plugin; all-platform Expo export completed successfully. Native device visual acceptance and release-binary icon/splash acceptance remain outstanding. The browser UI automation tool was unavailable during this pass.

Preview sign-in and registration by opening Account in the running app. Expo Go cannot reproduce the complete native launch experience. Validate the home-screen app icon, Android adaptive mask and splash transition in a signed installed release build. An EAS project and platform application identifiers/signing setup are still required before distributing such a build to the client.

8 October refinement: shared branded header and navy authentication introduction implemented. TypeScript, lint, mobile experience regression checks and iOS/Android/web export passed for this revision. Browser visual inspection was blocked by the UI automation runtime failure; physical device visual review remains required.

Additional presentation refinement: centered wordmark with symmetrical 44-point back/account controls, Playfair page headings, and a narrower authentication form capped at 520 points for tablets. Native splash uses a 350 ms fade after fonts resolve. Mobile typecheck and lint passed. UI automation failed to initialize, so physical-device visual acceptance is still required.

All-platform export passed after clearing the stale Metro cache: `/private/tmp/openhouse-brand-refinement-20261008`. Mobile experience regression checks passed. These checks confirm compilation/navigation, not physical-device visual acceptance.

October 8 demo refinement verification: header content now stays centered within 760 points with a responsive bounded wordmark; authentication password-toggle/link spacing is adjusted. Mobile TypeScript and zero-warning lint passed. Expo all-platform export completed for web/iOS/Android at `/private/tmp/openhouse-mobile-demo-verified`. This verifies bundling, not physical-device layout or an installed signed app. Native icon/splash configuration remains in app.config.ts; EAS/signing/identifiers and device acceptance are still required for client distribution.
