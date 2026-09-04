# 0720 — Persist Focus resize progress before gesture finalization

Status: Accepted

Date: 2026-09-04

Refines:

- [0715: Update recorded Focus at its source when resizing Planner evidence](0715-update-recorded-focus-at-its-source-when-resizing-planner-evidence.md)

## Context

The first source-backed Focus-resize implementation committed the owning
`FocusSession` only from the resize gesture's final callback. Production Planner
can begin with a cached data snapshot that has not yet loaded the session, and a
transient SwiftUI gesture can disappear without delivering its final callback.
In either case the continuously saved Calendar block changed while the Focus
session did not. Relaunch reconciliation then rebuilt the old rectangle from the
unchanged source.

Some older Calendar evidence can also retain the correct task, start, and
duration without retaining the canonical Focus-session block ID. Identity-only
lookup cannot connect such a rectangle to its source.

## Decision

When a completed Focus rectangle begins resizing, Planner resolves its owning
session from both the supplied presentation snapshot and the persistent model
context. Canonical block identity wins. If identity is unavailable, Planner may
recover an older relationship only when exactly one completed task- or tag-Focus
session produces the rectangle's original day, start minute, duration, and
recorded segment-start timestamp.
Ordinary task blocks remain independent when that match is absent or ambiguous.

Every accepted resize update applies the new start and duration to the resolved
Focus session before the existing Planner-block save. The source and visible
rectangle therefore reach durable storage together even if the gesture's final
callback is unavailable. When the final callback arrives, Planner removes every
captured legacy or segmented block, rebuilds canonical evidence, records the
activity update, publishes refresh notifications, and registers the combined
Undo/Redo operation.

## Consequences

- Task Details observes the changed Focus duration while the Planner block is
  changing rather than waiting on a fragile terminal callback.
- Force-quitting or reopening Routina after an accepted resize cannot restore the
  old interval from an unchanged Focus session.
- Older exact Focus evidence repairs itself to canonical session-backed evidence
  after a completed resize.
- A coincident ordinary task block is not treated as Focus evidence unless it has
  canonical identity or a unique exact historical-geometry and segment-start
  match.
