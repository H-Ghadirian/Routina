# Release Current Behavior

This page summarizes Routina's active versioning, platform scope, and release
documentation behavior. Decision records explain why these rules exist.

## Key Decisions

- [0416](../decisions/0416-use-semantic-release-versions.md)
- [0519](../decisions/0519-maintain-platform-versioned-release-notes.md)
- [0556](../decisions/0556-use-crashlytics-for-production-crash-stacks.md)
- [0568](../decisions/0568-defer-watch-companion-from-first-production-release.md)
- [0697](../decisions/0697-omit-apple-health-from-the-first-release.md)

## Current Contract

- Public versions use semantic `MAJOR.MINOR.PATCH` values and monotonically
  increasing Apple build numbers. Targets kept in the project stay
  version-aligned even when a platform is not part of the current distribution.
- Every applicable platform keeps independent release notes so its shipped
  features, fixes, limitations, and distribution status are explicit.
- The current release candidate is public version `1.4.0`, build `12`, for the
  universal iPhone/iPad app and macOS app. Its platform notes remain `In
  development` until the corresponding App Store versions ship. The earlier
  `1.3.1` draft was superseded before release and is not a shipment claim.
- Before either production app is distributed, the published policy and App
  Store Connect privacy answers must describe Firebase Crashlytics. The expected
  SDK declarations are Crash Data and Other Diagnostic Data for App
  Functionality, not linked to identity and not used for tracking; the final
  archive privacy report remains the release-time source of truth.
- The first production iOS phase ships the universal iPhone/iPad app and its
  production widget, but not the Apple Watch companion. `RoutinaiOSProd` does
  not build or embed `RoutinaWatchApp` and does not start the WatchConnectivity
  relay.
- The first production iOS phase also omits Apple Health UI, HealthKit code,
  Health privacy-purpose strings, and HealthKit entitlements.
- The Watch app, extension, models, and action handling remain in the project
  for a later release. Re-enabling the companion in production requires an
  explicit release decision and full production connectivity and performance
  verification.
