# 0037: Support Mac Home Back and Forward History

## Status

Accepted

## Date

2026-05-13

## Context

Mac Home has several user-visible navigation axes: sidebar mode, sidebar selection, the selected task, settings section, board scope, and the detail-column segmented mode. Users expect keyboard navigation to retrace those visible views in the same way browser and Finder history works.

## Decision

Mac Home keeps a window-scoped back/forward history of navigation snapshots. Each snapshot captures the visible Home navigation state rather than only a route name. `Command-Left Arrow` goes back and `Command-Right Arrow` goes forward.

When the user goes back and then chooses a different task, sidebar mode, settings section, board scope, or detail mode, the forward stack is cleared. Add-task sheets and filter-detail drill-ins are not recorded as Home history entries.

## Consequences

- Back and Forward restore complete Home views, including selected task details and Places mode.
- Choosing a new destination after going back starts a new branch, matching familiar macOS navigation behavior.
- The history is per window and temporary; it is not persisted across app launches.
