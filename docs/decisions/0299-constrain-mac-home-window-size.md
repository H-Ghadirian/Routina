# 0299: Constrain Mac Home Window Size for Planner Inspector

## Status

Accepted

## Date

2026-06-28

## Refines

- [0022: Own Mac Home Toolbar at the Split Shell](0022-own-mac-home-toolbar-at-split-shell.md)
- [0296: Present Mac Task Details as a Planner Inspector](0296-present-mac-task-details-as-planner-inspector.md)
- [0298: Close Fullscreen Mac Task Details to Planner](0298-close-fullscreen-mac-task-details-to-planner.md)

## Refined By

- [0345: Raise Mac Home Minimum Width for Sidebar Restore](0345-raise-mac-home-minimum-width-for-sidebar-restore.md)

## Context

Mac Home can present three work areas at once: the task sidebar, the Planner calendar, and a right-side task-detail companion pane. The previous 900 x 560 minimum window size allowed the window to shrink below the combined minimum space those surfaces need, causing the Planner and task-detail pane to visually collide.

The companion pane remains the right presentation for Planner task inspection, but the window should not resize into a broken intermediate state.

## Decision

Mac Home originally used a 1280 x 760 default window size and a 1200 x 720 minimum window size. The SwiftUI root content and the AppKit home-window configuration both enforced the same minimum so normal launches and fallback window presentation agreed. [0345](0345-raise-mac-home-minimum-width-for-sidebar-restore.md) later raised the active Home width contract.

The Planner task-detail companion pane renders only when the detail area can fit both the Planner's minimum content width and the fixed-width companion pane. If the detail area is externally constrained below that breakpoint, Planner remains visible, selected task state is preserved, and the companion pane reappears when enough width is available again.

No task, planner-block, focus, event, Away, Sleep, or persistence model changes are introduced.

## Consequences

- Mac Home no longer resizes into the overlapping Planner/task-detail state.
- Normal-width Planner task selection still opens the right-side companion task-detail pane.
- Extremely constrained detail widths prefer preserving the Planner calendar over squeezing both surfaces into unreadable columns.
- Future Mac Home layout changes should keep window minimums, split column minimums, and companion pane widths aligned.
