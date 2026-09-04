# 0295 — Do not defer durable drag state to mouse-up

Date: 2026-09-04

## Symptom

After the first Planner Focus-resize fix, dragging a completed Focus rectangle
still left the Task Details Focus total unchanged. The rectangle appeared resized
until Routina reopened, then returned to its old duration.

## Root Cause

The regression test called `endResizeBlock` directly and reused the same model
context. Production depended on two conditions that test bypassed: the cached
Planner snapshot had to contain the owning Focus session, and SwiftUI had to
deliver the drag's final callback. The visible block was persisted during drag,
but its authoritative `FocusSession` was saved only at the end. Older evidence
whose block ID no longer identified its session was also invisible to the
identity-only resolver.

## Fix

Planner now resolves completed Focus ownership from persistent sessions when the
presentation snapshot is stale, with a unique exact-geometry fallback for older
evidence. Each accepted resize mutates the owning session before the same save
that persists the block. Finalization still canonicalizes evidence, records the
change, refreshes consumers, and registers Undo/Redo, but durability no longer
depends on finalization.

## Prevention Rule

For a continuous gesture that edits authoritative persisted data, save the
authoritative value at each already-persisted accepted update or provide an
equivalent durable checkpoint. Treat mouse-up as finalization, not as the only
commit boundary, and test with stale presentation data plus a fresh model context.

## Regression Safeguard

`DayPlanPlannerStateTests.resizingCompletedTaskFocusPersistsBeforeGestureEndWhenPlannerSnapshotIsStale`
omits the final callback and verifies the result from a fresh model context.
`resizingLegacyFocusEvidenceRecoversItsSessionAndCanonicalizesPersistence`
verifies unique geometry recovery and canonical evidence after reopening.

Related decision: [0720 — Persist Focus resize progress before gesture finalization](../decisions/0720-persist-focus-resize-progress-before-gesture-finalization.md).
