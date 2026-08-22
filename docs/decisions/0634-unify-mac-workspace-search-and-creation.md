# 0634: Unify Mac Workspace Search and Creation

## Status

Accepted

## Date

2026-08-22

## Revises

- [0633: Make Mac Backlog Hierarchical and Searchable](0633-make-mac-backlog-hierarchical-and-searchable.md), for search placement and creation behavior

## Refines

- [0315: Merge Mac Quick Add Into Toolbar Search](0315-merge-mac-quick-add-into-toolbar-search.md)
- [0418: Keep Whole-History Work Out of Scrolling Render Paths](0418-keep-whole-history-work-out-of-scrolling-render-paths.md)
- [0632: Integrate Mac Workspaces in the Main Window](0632-integrate-mac-workspaces-in-the-main-window.md)

## Context

Planner already had a persistent `Search or create a task` field that could
filter both the task sidebar and calendar, expose where a task was scheduled,
and create a task only after search found no existing result. Backlog instead
placed a second search field inside its resizable sidebar, while Task Ladder had
no search. This made the top toolbar change meaning and availability when the
person switched between otherwise peer workspaces.

Moving either full workspace into Planner's native task sidebar would preserve
the toolbar but would discard useful resizable layouts, make Task Ladder's
ranking context too narrow, and couple those workflows to Planner's delicate
adaptive sidebar sizing.

## Decision

Planner, Backlog, and Task Ladder share the persistent top
`Search or create a task` control, but each workspace owns an independent query
and presentation. Switching workspaces changes the query target without
flattening their content or moving either workspace into Planner's sidebar.

Planner retains its existing task-list and calendar filtering. Backlog removes
its duplicate local field and applies the top query to its reducer-owned cached
presentation. Matching Backlog tasks remain in their hierarchy. A matching task
that exists outside Backlog appears in a separately labelled result with its
Radar, custom-path, completed, canceled, or archived location. It can be opened,
revealed in the workspace that owns its current context, or moved to an explicit
Backlog destination. Active, canceled, and archived matches hand off to Planner;
completed one-off matches hand off to Timeline because their evidence no longer
belongs in Planner's active task-list sidebar. The result summary itself opens
Task Details. It never counts as a Backlog result.

Backlog and Task Ladder embed Task Details inside their own split layouts. Those
embedded details do not contribute a second native principal title above the
shared toolbar. When leaving Backlog with a detail open, Routina removes that
embedded detail before replacing the workspace split hierarchy.

Task Ladder search inspects all searchable task metadata plus Ladder ancestor
names. Eligible matches report their nested scope and current metric section;
choosing `Locate` navigates to that scope, expands the matching value section,
highlights the row, and keeps the Ladder order intact. Matching tasks excluded
from Task Ladder remain separate and explain the applicable lifecycle, Blocked,
Flag, or prerequisite reason.

Creation remains globally task-duplicate-aware. Planner retains its existing
task-and-Timeline result behavior; Backlog and Task Ladder use task matches
because those workspaces do not present Timeline activity. When no applicable
result matches, Planner and Task Ladder keep toolbar Quick Add. Backlog first asks for
an explicit Backlog section, with `Main task list` as the clear user-facing
alternative for the normal Radar, and opens the seeded full task form. Backlog
never silently invents an unsectioned destination.

All search presentations rebuild at task, organization, Flag-rule, metric, or
query invalidation boundaries. Scrolling rows consume cached results.

## Consequences

- The top toolbar remains predictable across the three task workspaces.
- Planner keeps its calendar-location benefit, while Backlog and Task Ladder
  keep their resizable full-workspace layouts.
- Search scope is visible: finding an existing task never implies that it
  belongs to the active workspace and never encourages a duplicate.
- Completed search matches lead to Timeline history, while active organizational
  matches lead to Planner; embedded details do not add competing window chrome.
- Backlog creation remains consistent with its explicit-destination model.
- Task Ladder search preserves hierarchy and ranking instead of replacing the
  ladder with a flat, reordered result list.
