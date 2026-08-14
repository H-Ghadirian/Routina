# 0569 — Suppress No-op Preference Sync Refresh Loops

**Status:** Accepted
**Date:** 2026-08-14

## Refines

- [0210 — Store Durable Preferences in SwiftData](0210-store-durable-preferences-in-swiftdata.md)
- [0418 — Keep Whole-History Work Out of Scrolling Render Paths](0418-keep-whole-history-work-out-of-scrolling-render-paths.md)
- [0543 — Defer iOS Sync Refresh Work Until Its Tab Is Active](0543-defer-ios-sync-refresh-work-until-its-tab-is-active.md)
- [0567 — Defer iOS Home Refreshes Until Scrolling Is Quiet](0567-defer-ios-home-refreshes-until-scrolling-is-quiet.md)

## Context

A physical-device production trace of opening, searching, clearing, and closing
iOS Search showed repeated complete Home loads even when the person was idle.
The loads followed CloudKit surface refreshes every few seconds and each spent
roughly 250–350 milliseconds in the main-actor task-load and display pipeline.

Home persisted `TemporaryViewState` after every successful load even when
filter validation changed nothing. Writing the same value still scheduled the
durable preference mirror. That mirror unconditionally advanced the singleton
preference record's `updatedAt` and saved every copied field, even when the
durable values already matched. The resulting CloudKit activity produced the
next semantic surface refresh and could repeat the cycle.

## Decision

The `UserDefaults` and `RoutinaUserPreferences` bridge is semantic and
change-aware in both directions:

- Mirroring defaults into SwiftData mutates only unequal durable fields and
  saves or advances `updatedAt` only when the singleton is new or a durable
  value actually changed.
- Applying a synchronized SwiftData preference record writes only unequal
  defaults. Applying the same record again performs no writes.
- Device-local `TemporaryViewState` compares its decoded value before writing
  and never schedules the durable SwiftData preference mirror.
- A Home task load persists temporary view state only when catalog validation
  actually prunes or changes a stored task filter. Deliberate filter actions
  continue to persist immediately.

CloudKit import notifications remain correctness invalidations for task and
history data. Routina does not discard an import merely because durable
preferences were unchanged; instead, no-op local state writes must not create
new persistence and CloudKit activity in the first place.

## Consequences

- An ordinary Home reload can no longer manufacture another CloudKit-backed
  refresh from unchanged temporary or durable preferences.
- Real cross-device preference edits still update defaults, save once, and
  become visible through existing Settings and Home presentation paths.
- A real task or history import still refreshes the active surface after the
  existing coalescing, active-tab, and scroll-quiet boundaries.
- Every new durable preference must participate in both change-aware bridge
  directions; unconditional timestamp-only preference saves are prohibited.
