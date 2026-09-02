# 0713 — Retain Project-Local Xcode Build Caches

**Status:** Accepted
**Date:** 2026-09-02

## Refines

- [0238 — Use Project-Local Mac Dev Run Entrypoint](0238-use-project-local-mac-dev-run-entrypoint.md)
- [0248 — Add Explicit Mac Prod Run Entrypoint](0248-add-explicit-mac-prod-run-entrypoint.md)
- [0566 — Keep Production iOS Profiling Setup Warm but Disposable](0566-keep-production-ios-profiling-setup-warm-but-disposable.md)

## Context

Routine verification previously created isolated project-local Derived Data
directories and deleted every one at completion. That kept the working tree
clean, but it also discarded compiled dependencies, modules, indexes, and
incremental build records after every successful build. The next verification
therefore paid the cost of another cold build even when Xcode could safely
increment only the changed sources.

Cold caches are useful when diagnosing cache corruption and isolated build
products remain necessary for trustworthy profiling. They are not a general
correctness requirement for ordinary development builds. Git ignore rules can
keep generated caches out of commits without deleting them.

## Decision

Normal Xcode development and verification builds retain target-specific caches
under `.build/xcode-derived-data/`, which is ignored by the repository. Stable
paths are reused across sessions for macOS development and production, iOS
Simulator development, and iOS device development builds.

Completion cleanup stops apps launched for verification but preserves normal
Derived Data. A target cache is deleted only for an explicitly requested clean
build or when a demonstrated cache failure requires a targeted rebuild. A
problem with one target does not justify clearing every platform cache.

Routine iOS verification builds and launches the Simulator target once. A
second generic physical-device build is required only when signing,
capabilities, or device-only behavior are in scope.

Profiling remains a separate trust boundary: session-specific app products,
symbols, traces, logs, helpers, and profiling Derived Data stay isolated and
disposable as required by Decisions 0542, 0547, and 0566. The persistent iOS
package-support cache defined by Decision 0566 also remains unchanged.

## Consequences

- Unchanged dependencies and source files can be reused, substantially reducing
  routine verification time after the first build.
- Generated build artifacts remain outside version control without requiring
  completion-time deletion.
- Local disk usage grows until a contributor intentionally removes an obsolete
  or unhealthy target cache.
- Targeted clean builds remain available as a recovery step without penalizing
  unrelated platforms.
- Profiling artifact isolation and mandatory profiling cleanup are unchanged.
