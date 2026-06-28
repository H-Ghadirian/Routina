# 0310: Show Mac Home Toolbar Search

## Status

Accepted

## Date

2026-06-28

## Refines

- [0022: Own Mac Home Toolbar at Split Shell](0022-own-mac-home-toolbar-at-split-shell.md)
- [0244: Start Mac Toolbar Focus With Task Picker](0244-start-mac-toolbar-focus-with-task-picker.md)
- [0309: Show Full Timeline in Planner List Mode](0309-show-full-timeline-in-planner-list-mode.md)

## Context

Mac Home already had search fields in contextual sidebar surfaces, and the Search tab can bind Home to an external search query. That kept search available, but it made the affordance dependent on the current surface instead of being visible near the main Home actions.

The toolbar also owns the global `Start Focus Timer` entry point. Search belongs near that action because both are high-frequency, app-wide Home controls.

Rendering a second task/timeline search `TextField` in the sidebar with the same shared binding causes macOS SwiftUI/AppKit first-responder focus to jump from the toolbar field to the sidebar field during typing. Even with that duplicate removed, a pure SwiftUI toolbar `TextField` can still lose focus after a character because each search update rebuilds enough Home toolbar/list state.

## Decision

Mac Home shows an AppKit-backed search field in the window toolbar navigation area beside the Focus Timer controls. The field uses the existing Home search binding so the same query filters task lists, Timeline-style lists, Planner List mode's full Timeline surface, and task-backed Planner Calendar items. Planner Calendar search filtering is presentation-only: it hides non-matching planned task blocks, all-day task items, planned-date task counts, and automatic task timeline suggestions without changing stored Planner blocks or layer filter state. The bridge lets `NSSearchField` own the active editor and restores first responder after Home re-filters. The task/timeline sidebar keeps filter controls but does not render a duplicate text input for that same binding. Goals may keep its separate sidebar search because it uses independent Goals search state.

The Focus Timer toolbar branch remains the single timer slot: active timers, disabled timer badges, and the `Start Focus Timer` menu still occupy the same mutually exclusive branch.

## Consequences

Users can search tasks and Timeline entries from the top of Home without first opening a sidebar search surface, and keyboard focus stays in the toolbar field while typing.

Future toolbar changes should preserve the search field as a global Home affordance while keeping focus-timer start and active-timer presentation mutually exclusive.
