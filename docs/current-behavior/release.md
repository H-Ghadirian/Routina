# Release Current Behavior

This page summarizes Routina's active versioning, platform scope, and release
documentation behavior. Decision records explain why these rules exist.

## Key Decisions

- [0416](../decisions/0416-use-semantic-release-versions.md)
- [0519](../decisions/0519-maintain-platform-versioned-release-notes.md)
- [0556](../decisions/0556-use-crashlytics-for-production-crash-stacks.md)
- [0568](../decisions/0568-defer-watch-companion-from-first-production-release.md)
- [0697](../decisions/0697-omit-apple-health-from-the-first-release.md)
- [0704](../decisions/0704-maintain-versioned-app-store-metadata.md)
- [0709](../decisions/0709-defer-ipad-support-until-it-is-ready.md)

## Current Contract

- Public versions use semantic `MAJOR.MINOR.PATCH` values and monotonically
  increasing Apple build numbers. Targets kept in the project stay
  version-aligned even when a platform is not part of the current distribution.
- Every applicable platform keeps independent release notes so its shipped
  features, fixes, limitations, and distribution status are explicit.
- Every platform version with prepared or verified App Store copy keeps one
  `MAJOR.MINOR.PATCH-app-store.md` companion document. It preserves the exact
  Description, What's New, and any other used public metadata without treating
  that copy as a substitute for verified release scope.
- The current release candidate is public version `1.4.0`, build `12`, for the
  iPhone app and macOS app. Their platform notes remain `In development` until
  the corresponding App Store versions ship. The prepared iPadOS candidate is
  `Deferred before release`; adaptive iPad source remains in the repository but
  is not a supported or release-ready surface. The earlier `1.3.1` draft was
  superseded before release and is not a shipment claim.
- Before either production app is distributed, the published policy and App
  Store Connect privacy answers must describe Firebase Crashlytics. The expected
  SDK declarations are Crash Data and Other Diagnostic Data for App
  Functionality, not linked to identity and not used for tracking; the final
  archive privacy report remains the release-time source of truth.
- The first production iOS phase ships the iPhone app and its production
  widget, but neither an iPad app nor the Apple Watch companion. Every iOS app,
  test-bundle, and widget configuration targets device family `1`, and the app
  Info.plists have no iPad-specific orientation declarations. `RoutinaiOSProd`
  does not build or embed `RoutinaWatchApp` and does not start the
  WatchConnectivity relay.
- The first production iOS phase also omits Apple Health UI, HealthKit code,
  Health privacy-purpose strings, and HealthKit entitlements.
- The Watch app, extension, models, and action handling remain in the project
  for a later release. Re-enabling the companion in production requires an
  explicit release decision and full production connectivity and performance
  verification.
- Adaptive iPad code may remain for later work. Restoring iPad support requires
  an explicit scope decision, restored device-family configuration, updated
  product documentation, and complete iPad functional, layout, performance,
  archive, and launch verification.
