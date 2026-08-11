# 0545: Bound iOS Foreground Focus Reconciliation

## Status

Accepted

## Date

2026-08-11

## Refines

- [0418: Keep Whole-History Work Out of Scrolling Render Paths](0418-keep-whole-history-work-out-of-scrolling-render-paths.md)
- [0542: Use Validated Release Device Traces for iOS Performance Investigations](0542-use-validated-release-device-traces-for-ios-performance-investigations.md)
- [0543: Defer iOS Sync Refresh Work Until Its Tab Is Active](0543-defer-ios-sync-refresh-work-until-its-tab-is-active.md)

## Context

Validated Release traces from a physical iPhone showed that foregrounding could
freeze Home, Search, and Timeline. The active-Focus reconciliation started a
private-zone fetch with no server-change token, which replayed the complete
SwiftData CloudKit zone on every launch and foreground transition. Its merge
and every deletion cleanup ran on the main actor. For a large tombstone set,
each deleted record also initiated a separate whole-history cleanup scan.

## Decision

Foreground active-Focus reconciliation queries only the active SwiftData
CloudKit Focus record types, plus directly fetches the current remote rows for
the bounded set of locally active Focus IDs so a remote stop is visible. It
must not replay the private zone. The explicit manual `Sync Now` path may still
request a full zone reconciliation, but applies all received deletion IDs in
one batch and scans each related model family at most once per pull.

## Consequences

- Foreground and keyboard work no longer compete with a full remote history
  replay or repeated deletion scans.
- A remotely active task or sprint Focus session remains discoverable before
  SwiftData's ordinary import finishes.
- Explicit recovery sync remains available, with bounded per-pull cleanup work
  rather than work that grows with both tombstones and retained history.
