# 0556: Use Crashlytics for Production Crash Stacks

## Status

Accepted

## Date

2026-08-12

## Refines

- [0553: Record Debug Performance Symptoms for Support](0553-record-debug-performance-symptoms-for-support.md)
- [0554: Correlate Debug Stalls With Safe Interaction Trails](0554-correlate-debug-stalls-with-safe-interaction-trails.md)
- [0555: Preserve the Previous Debug Performance Run](0555-preserve-the-previous-debug-performance-run.md)

## Context

The Debug JSON performance profile survives most abrupt exits and explains CPU,
memory, stalls, and the broad action preceding them. It does not contain the
crashed thread, exception, binary image UUIDs, or symbolicated function names,
so it cannot diagnose crashes reported by App Store users on its own.

MetricKit can deliver Apple diagnostic payloads, but delivery is delayed and it
requires the user to relaunch the app. Routina needs an initial automated crash
stack service with grouping, affected-build context, and dSYM symbolication.

## Decision

The iOS and macOS application targets use Firebase Crashlytics as the primary
production crash stack provider. The three distinct production, iOS development,
and macOS development bundle IDs use separate Firebase Apple app registrations.
If a matching local
`GoogleService-Info.plist` is absent, the integration is a safe no-op and the app
continues to launch.

Crashlytics collection is automatic once configured. Google Analytics is not
linked. Routina does not set a Crashlytics user identifier. Custom context is
limited to platform, development/production variant, and the same closed,
privacy-safe interaction enum defined by Decision 0554. Rapid repeated categories
are coalesced before logging.

Builds that produce dSYMs upload them with Firebase's supported build script,
including Xcode's Debug dylib symbols. The macOS bundles enable Keychain Sharing
and `NSApplicationCrashOnExceptions`, as required by Firebase's Apple platform
setup guidance. The SwiftUI apps retain their existing delegate adaptors and
disable Firebase app-delegate swizzling. An explicit Debug-only Xcode environment
variable schedules Firebase's required verification crash and is compiled out of
Release builds. The Debug JSON profile remains the shareable performance
handoff, and Instruments remains the authority for performance function stacks.

MetricKit is deferred until Crashlytics evidence shows a meaningful diagnostic
gap, such as hangs, launch failures, or system terminations absent from the
Crashlytics reports.

## Consequences

- User crashes can arrive automatically with grouped, symbolicated stacks after
  the next launch and network delivery.
- Firebase app registrations and their downloaded configuration plists are
  deployment inputs rather than source-controlled files.
- App Store privacy disclosures and Routina's privacy policy must describe
  Crashlytics diagnostic collection before production distribution.
- A crash report and the optional Debug JSON profile complement each other: one
  supplies the function stack; the other supplies performance symptoms and a
  longer bounded interaction timeline.
