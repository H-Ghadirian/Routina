# 0559: Run Startup Data Maintenance Off the Main Actor

## Status

Accepted

## Date

2026-08-13

## Refines

- [0418: Keep Whole-History Work Out of Scrolling Render Paths](0418-keep-whole-history-work-out-of-scrolling-render-paths.md)
- [0543: Defer iOS Sync Refresh Work Until Its Tab Is Active](0543-defer-ios-sync-refresh-work-until-its-tab-is-active.md)

## Context

An iOS Debug performance profile recorded 1.14-second and 831-millisecond
main-thread stalls immediately after launch. The startup path ran persistence
migrations twice and Home's first snapshot also performed complete-history
deduplication, log repair, and orphan cleanup on the main actor.

Those scans are correctness maintenance, not work required to render the
first interactive Home surface. Running them during scene activation delayed
the first visible interaction and could leave the loading presentation active
longer than necessary.

## Decision

One utility-priority `@ModelActor` worker performs post-open recurrence and
checklist migrations plus startup data integrity repair with its own SwiftData
context. App-scene bootstrap performs only the compact preferences migration
on the main actor, then starts that worker once per process.

Home's initial visible data load no longer performs maintenance. If the
background worker changes data, it posts one normal update on the main actor;
surfaces then refresh through their existing lightweight invalidation paths.

## Consequences

- First Home rendering does not share the main actor with complete-history
  migration, deduplication, backfill, or orphan deletion.
- Startup repair remains serialized and complete before emitting one UI
  invalidation, rather than producing intermediate update cascades.
- A background maintenance pass can consume CPU on unusually large stores,
  but it no longer blocks scene activation or touch handling.
- Regression tests guard the detached model-actor boundary and prohibit
  reintroducing initial Home maintenance on the UI executor.
