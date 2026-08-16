# 0590: Use Progress-Aware Incremental Manual iCloud Refresh

## Status

Accepted

## Date

2026-08-16

## Supersedes

- [0589: Bound Manual iCloud Refresh](superseded/0589-bound-manual-icloud-refresh.md)

## Refines

- [0523: Report Manual iCloud Refresh Honestly](0523-report-manual-icloud-refresh-honestly.md)
- [0545: Bound iOS Foreground Focus Reconciliation](0545-bound-ios-foreground-focus-reconciliation.md)
- [0418: Keep Whole-History Work Out of Scrolling Render Paths](0418-keep-whole-history-work-out-of-scrolling-render-paths.md)

## Context

Decision 0589 prevented an endless Settings or Home refresh by imposing one
absolute 60-second deadline. A production first refresh showed why that rule
was too blunt: the explicit pull can legitimately stream a complete private
SwiftData zone for longer than one minute, but the app canceled it even while
CloudKit was still delivering records. Because every pull also started from a
nil server-change token, each retry replayed the same full zone and its
tombstones instead of becoming cheaper after a successful reconciliation.

Routina still needs a product-owned terminal state. CloudKit can stop calling
back, system request defaults are not an interactive progress policy, and a
partial fetch must never advance local synchronization past records that were
not merged.

## Decision

Settings `Sync Now`, iOS Home pull-to-refresh, and the Mac Home sync action use
one progress-aware direct CloudKit pull. The request has a 60-second inactivity
watchdog that restarts whenever a changed record, deleted record, record-level
result, or zone progress result arrives. A separate three-minute hard limit
prevents a continuously active request from owning an interactive surface
indefinitely. Calling-task cancellation still cancels and completes the
underlying CloudKit operation.

The first pull for a configured iCloud container starts without a server-change
token and reads the full SwiftData zone. After the complete response merges and
the local context saves successfully, Routina archives the returned token for
that container. Later manual pulls start from that token and fetch only newer
changes. A record-level failure, terminal fetch failure, cancellation, timeout,
or local merge failure does not advance the token. If CloudKit reports an
expired token, Routina clears it and retries one full pull. Destructive cloud
reset and backup import also invalidate direct-pull tokens because their local
or remote baseline has changed.

Settings identifies whether it is checking all iCloud data or recent changes,
reports received-item progress during a long pull, and records the actual
manual-refresh mode, counts, outcome, and sanitized error in copyable
diagnostics. Settings and Home retain the shared recovery contract: visible
progress ends on failure, existing local data remains usable, and the person is
told what to check before retrying. A successful result still confirms only the
manual download; system-managed uploads remain asynchronous under Decision
0523.

## Consequences

- A legitimately progressing initial reconciliation is no longer mistaken for
  a stall at the one-minute mark.
- A silent request still ends after one minute without activity, and every
  manual request has a three-minute maximum interaction budget.
- Successful later refreshes are normally incremental instead of repeatedly
  replaying the complete SwiftData zone.
- Token advancement shares the complete-response-and-merge boundary, so a
  retry cannot silently skip data that failed to reach the local store.
- The first refresh, a refresh after token expiry, reset, or import, and a very
  large change set can still take longer or reach the hard limit; diagnostics
  distinguish those cases from a request that never delivered data.
