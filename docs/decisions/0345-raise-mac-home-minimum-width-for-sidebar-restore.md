# 0345: Raise Mac Home Minimum Width for Sidebar Restore

## Status

Accepted

## Date

2026-07-05

## Refines

- [0299: Constrain Mac Home Window Size for Planner Inspector](0299-constrain-mac-home-window-size.md)
- [0343: Add Mac Home Sidebar Collapse Control](0343-add-mac-home-sidebar-collapse-control.md)
- [0344: Clamp Mac Home Sidebar Width](0344-clamp-mac-home-sidebar-width.md)

## Context

Mac Home can show the left sidebar, Planner, and a right-side companion pane at the same time. The 1200-point minimum width was enough for some final layouts but left too little room for the animated transition that restores the left sidebar. At narrow widths, expanding the sidebar could push the Planner/detail area rightward during the animation before the split view settled.

## Decision

Mac Home now uses a 1440 x 760 default window size and a 1440 x 720 minimum window size. The SwiftUI root content and AppKit home-window configuration continue to use the same `RoutinaMacWindowSizing` constants. The sidebar expand/collapse action keeps the normal sidebar animation, and the window does not use dynamic content-minimum resizing to grow during the toggle.

## Consequences

- Users cannot resize Mac Home below the width where the expanded sidebar, Day-capable Planner surface, and right-side companion pane have transition breathing room.
- The sidebar restore can stay animated without pushing the right-side companion pane off the visible window at supported window widths.
- The Home window occupies more horizontal space than the previous 1200-point minimum.
