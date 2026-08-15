# 0164 — Cache task-detail sidebar locations

Date: 2026-08-15

## Symptom

On a production Mac build with a large task catalog, selecting different tasks
and moving Task Detail between the companion pane and fullscreen caused visible
animation hitches.

## Root Cause

The Task Detail render path asked Home for the selected task's live sidebar
breadcrumb. That helper called `macTaskListPresentation`, which rebuilt an
equality signature by reading and sorting relationship state from every task
even when the presentation itself was already cached. It then scanned the
presentation sections and groups to find one task. The sidebar's own cache
validation repeated the same all-task relationship signature work during
otherwise unrelated layout updates. SwiftUI reevaluated these paths while the
detail layout was transitioning.

## Fix

`HomeMacTaskListPresentationCache` now derives task-ID-to-sidebar-location
snapshots alongside each new task-list presentation. Task Detail reads the
section, nested group titles, and task flags with a constant-time dictionary
lookup, so transition-time rendering no longer constructs the whole-history
presentation signature or searches the task catalog. Home display refreshes
now derive active relationship-blocker IDs once and store that state on the
immutable task displays. The sidebar presentation signature uses the existing
display revision instead of remapping and sorting every SwiftData task merely
to validate an unchanged cache.

## Prevention Rule

When a detail, row, toolbar, or other render path needs metadata derived from a
large presentation, cache an immutable lookup with that presentation. A cache
getter must not rebuild its full input signature merely to return a previously
derived value.

## Regression Safeguard

`PerformanceRegressionTests.testMacTaskDetailsUseLiveSidebarLocationAndExistingRevealPath`
asserts that the breadcrumb uses `macTaskListPresentationCache.sidebarLocation`
and that the render-path helper cannot call `macTaskListPresentation` or scan
`store.routineTasks`.
`PerformanceRegressionTests.testMacTaskListSignatureDoesNotWalkRoutineTasksFromRenderPath`
keeps relationship derivation at the Home display refresh boundary and out of
the presentation signature and row predicate. This reinforces
[Decision 0418](../decisions/0418-keep-whole-history-work-out-of-scrolling-render-paths.md).
