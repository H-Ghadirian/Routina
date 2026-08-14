# 0566 — Keep Production iOS Profiling Setup Warm but Disposable

**Status:** Accepted
**Date:** 2026-08-14

## Refines

- [0542 — Standardize Production iOS Profiling on a Physical Device](0542-standardize-production-ios-profiling-on-a-physical-device.md)
- [0547 — Require Trustworthy Artifacts for Physical iOS Profiling](0547-require-trustworthy-artifacts-for-physical-ios-profiling.md)

## Context

A production iOS profiling launch took about 12 minutes before the app was
ready on the physical device. Most of that delay came from a cold, isolated
Release build that had to resolve package support, compile the application and
Watch extension, sign the products, and generate matching symbols. An initial
build invocation also lacked the Xcode filesystem access it needed, and the
command wrapper returned before the underlying `xcodebuild` process finished.

The trustworthy-artifact rules still require a fresh session-specific Derived
Data directory and exact matching app and dSYM artifacts. Reusing old
application products would make profiling faster at the cost of confidence in
the results. Repeating dependency repository and download work does not
improve profiling validity.

The production build's Crashlytics upload phase currently locates Firebase
relative to Derived Data. Moving cloned packages to a separate shared checkout
directory with `-clonedSourcePackagesDirPath` would therefore break an existing
build assumption unless that phase were changed and verified separately.

## Decision

Production iOS profiling will keep every session's application build products,
symbols, traces, exports, logs, and helpers isolated and disposable. The
project may retain one package-support cache at
`.codex/IOSBuildPackageCache/`; it must not contain reusable Routina
application products, Routina dSYMs, profiling traces, or exports.

The first build invocation must run with the Xcode access required for device
and package operations. Profiling builds should use:

- `-packageCachePath .codex/IOSBuildPackageCache`
- `-skipPackageUpdates`
- `-disableAutomaticPackageResolution`
- `-showBuildTimingSummary`

The operator must wait for the actual `xcodebuild` process to finish even if a
command wrapper returns early. Once the app and dSYM have been validated, that
exact build should be installed immediately and reused for every trace in the
same unchanged-worktree profiling session.

Do not introduce a shared `-clonedSourcePackagesDirPath` until the Crashlytics
build phase and all other package-path assumptions have been updated and the
production build has been verified.

## Consequences

- Subsequent profiling sessions avoid repeating eligible package repository
  and download work.
- A clean optimized Release compilation, signing, and symbol generation still
  occur, so this does not promise an instant launch.
- Exact binary and dSYM validation, physical-device profiling, and complete
  session-artifact cleanup remain unchanged.
- The persistent package-support cache is ignored by Git and is not removed by
  normal profiling-session cleanup.
