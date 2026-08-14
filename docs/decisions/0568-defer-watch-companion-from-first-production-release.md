# 0568 — Defer the Watch Companion from the First Production Release

**Status:** Accepted
**Date:** 2026-08-14

## Refines

- [0032 — Sync Active Sleep Mode Across Devices](0032-sync-active-sleep-mode-across-devices.md)
- [0106 — Support Unassigned Watch Focus Sessions](0106-support-unassigned-watch-focus-sessions.md)
- [0416 — Use Semantic Release Versions](0416-use-semantic-release-versions.md)
- [0519 — Maintain Platform-Versioned Release Notes](0519-maintain-platform-versioned-release-notes.md)

## Context

Routina already contains a Watch app, Watch extension, and an iPhone
WatchConnectivity relay. The production iOS target built and embedded the Watch
app and started the relay whenever the phone app launched.

The first production phase is intentionally limited to the iPhone and iPad app.
Shipping a companion now would broaden release testing and support obligations.
It would also keep the relay active even though the companion is outside this
phase; that relay derives and sends task and Focus snapshots and was visible in
the main-thread work investigated during production performance profiling.

The existing Watch product decisions remain useful implementation intent for a
later phase. Removing their source or data compatibility would create needless
rework.

## Decision

`RoutinaiOSProd` will not depend on or embed `RoutinaWatchApp`, and the
production iOS app will not start `WatchRoutineSyncBridge`. The development app
may continue to start the bridge so the retained companion implementation can
be exercised before its release phase.

Keep the Watch app and extension targets, source, models, action handling, and
version metadata in the project. They are dormant release work, not deleted
functionality. Reintroducing the companion to the production target requires an
explicit release-scope decision plus production build, installation,
connectivity, and performance verification.

The watchOS release history must state that the companion is deferred. When a
Watch build becomes applicable again, its public version and build metadata
remain aligned with the containing iOS release under Decision 0416.

## Consequences

- The phase-one production archive contains no Watch app or extension.
- Production launches avoid WatchConnectivity snapshot-relay work.
- The first release has no Apple Watch companion or Watch-originated actions.
- Development can preserve and test the existing companion without rebuilding
  the feature from scratch later.
- Production builds no longer spend time compiling and signing the Watch
  dependency, reducing one source of clean-build delay.
