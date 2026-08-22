# 0632: Integrate Mac Workspaces in the Main Window

## Status

Accepted

## Date

2026-08-22

## Revises

- [0546: Separate Mac Backlog From the Radar Sidebar](0546-separate-mac-backlog-from-the-radar-sidebar.md), for Backlog presentation
- [0561: Add a Separate Mac Task-Ranking Ladder](0561-add-separate-mac-task-ranking-ladder.md), for Task Ladder presentation
- [0332: Remove Settings From Mac Home Toolbar Strip](0332-remove-settings-from-mac-home-toolbar-strip.md), for Settings discoverability

## Refines

- [0316: Present Mac Home Filters as a Companion Pane](0316-present-mac-home-filters-as-companion-pane.md)
- [0343: Add Mac Home Sidebar Collapse Control](0343-add-mac-home-sidebar-collapse-control.md)

## Context

Backlog and Task Ladder were complete Mac workflows, but they could only be
discovered through the app menu and opened in separate windows. That split made
them feel detached from Planner, Stats, and Add Task, and introduced avoidable
window focus and state-restoration problems.

The top-right compact mode strip mixed workspace navigation with creation while
communicating destinations only through small icons. A Telegram-style overlay
drawer would make those destinations more visible, but it would introduce a
second drawer model beside Routina's native left task sidebar and its existing
right-side contextual panes for filters, dates, and task details.

## Decision

The main Mac window uses one labeled workspace menu in its top toolbar. It
offers Planner, Backlog, Task Ladder, Stats, and any enabled Goals or Adventure
workspaces. Settings is visible in the same menu but opens Routina's standard
macOS Settings window. Creation remains a separate `New` control rather than a
workspace segment.

Backlog and Task Ladder render as full-size peer workspaces inside the main
window and share the root app store. They retain their own internal split-view
layouts, selection, editing, refresh, and ranking state. They no longer create
separate scenes. The existing Shift-Command-B and Shift-Command-R commands
activate the main window and select the corresponding workspace.

The native left task sidebar remains Planner's task-navigation surface. Its
toggle is hidden while Backlog or Task Ladder owns the full workspace. The
right side remains reserved for one contextual companion pane at a time, such
as filters, Go to date, or task details. Routina does not add a global overlay
drawer on either side.

## Consequences

- Backlog and Task Ladder are visible from the same persistent navigation
  control as Planner and Stats.
- Switching workflows stays inside one window and avoids detached-window focus
  and restoration problems.
- The labeled menu scales better than adding more icon-only segments to the
  titlebar.
- Settings follows the expected macOS window convention while remaining easy
  to discover.
- Left-side global/task navigation and right-side contextual controls keep
  distinct roles, avoiding two competing drawers on the same edge.
