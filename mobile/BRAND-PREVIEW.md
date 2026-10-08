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
