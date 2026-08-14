# Release Current Behavior

This page summarizes Routina's active versioning, platform scope, and release
documentation behavior. Decision records explain why these rules exist.

## Key Decisions

- [0416](../decisions/0416-use-semantic-release-versions.md)
- [0519](../decisions/0519-maintain-platform-versioned-release-notes.md)
- [0568](../decisions/0568-defer-watch-companion-from-first-production-release.md)

## Current Contract

- Public versions use semantic `MAJOR.MINOR.PATCH` values and monotonically
  increasing Apple build numbers. Targets kept in the project stay
  version-aligned even when a platform is not part of the current distribution.
- Every applicable platform keeps independent release notes so its shipped
  features, fixes, limitations, and distribution status are explicit.
- The first production iOS phase ships the universal iPhone/iPad app and its
  production widget, but not the Apple Watch companion. `RoutinaiOSProd` does
  not build or embed `RoutinaWatchApp` and does not start the WatchConnectivity
  relay.
- The Watch app, extension, models, and action handling remain in the project
  for a later release. Re-enabling the companion in production requires an
  explicit release decision and full production connectivity and performance
  verification.
