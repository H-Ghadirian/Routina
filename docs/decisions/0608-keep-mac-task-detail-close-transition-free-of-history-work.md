# 0608 — Keep Mac Task Detail close transitions free of history work

Status: Accepted

Date: 2026-08-18

Refines: [0418: Keep Whole-History Work Out of Scrolling Render Paths](0418-keep-whole-history-work-out-of-scrolling-render-paths.md), [0296: Present Mac Task Details as a Planner Inspector](0296-present-mac-task-details-as-planner-inspector.md)

## Context

Closing the Mac Planner task-detail companion pane widens the calendar and can change its effective Day, 3 Days, or Week range. That layout transition previously triggered count-up Focus reconciliation even though the underlying Focus data had not changed. Reconciliation walked all eligible Focus sessions and saved every reconstructed segment individually, including blocks already identical to storage.

The open companion pane also intentionally deferred Home's semantic routine-update refresh. Closing the pane released that full task and history reload inside the same animated transition. Profiling showed the adaptive range change, repeated SwiftData writes, Home snapshot reload, and SwiftUI relayout competing on the main actor while the pane was closing.

## Decision

Adaptive Planner range changes load the newly visible Planner days and exact-time task presentation without reconciling Focus history. Focus reconciliation remains available at lifecycle and data-revision boundaries where persisted Focus evidence may genuinely have changed.

When reconciliation runs, it constructs the required segment blocks first, groups them by day, compares them with stored blocks, and saves each changed day at most once. A day whose generated blocks are already identical performs no save.

When a Mac task-detail pane closes with a deferred Home refresh pending, Home schedules that refresh after a 450-millisecond transition quiet window instead of starting it in the close transaction. The refresh remains mandatory and retains the existing scroll-interaction deferral.

## Consequences

- Closing Task Details preserves the existing Planner context and adaptive range without putting historical Focus repair or a full Home reload in the animation.
- Count-up Focus repair remains correct after launch, data changes, sync, and foreground activation while no-op repair stops producing SwiftData invalidations.
- Several repaired Focus segments on one day require one load/save cycle instead of one cycle per segment.
- Tests must protect both the no-op persistence boundary and the absence of Focus reconciliation from the adaptive range handler.
