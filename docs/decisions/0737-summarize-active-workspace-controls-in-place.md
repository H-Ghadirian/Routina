# 0737 — Summarize Active Workspace Controls in Place

## Status

Accepted

## Date

2026-09-05

## Refines

- [0188 — Prefer Self-Explanatory UI Over Instructional Copy](0188-prefer-self-explanatory-ui-over-instructional-copy.md)
- [0722 — Move Mac Task Ladder Controls to the Right Sidebar](0722-move-mac-task-ladder-controls-to-the-right-sidebar.md)
- [0727 — Move Mac Backlog Status Out of the List Header](0727-move-mac-backlog-status-out-of-the-list-header.md)
- [0736 — Give iOS Workspaces Scope-Aware Controls](0736-give-ios-workspaces-scope-aware-controls.md)

## Context

Tinting a controls icon says that something changed, but it does not tell the
person what is shaping the rows they see. That uncertainty is especially costly
after moving between Main Task List, Backlog, and Task Ladder, because each
workspace deliberately owns different controls. Reopening a sheet or companion
pane just to rediscover the current metric, filter count, or order adds repeated
review work.

The summary must not restore the permanent list-level control bars and workspace
headers removed from Backlog and Task Ladder. Those lists should still dedicate
their first content to deferred or ranked work.

## Decision

- Main Task List, Backlog, and Task Ladder derive active-control summaries from
  the same state that drives their controls. The shared summary vocabulary keeps
  `Filter`, `View`, `Sort`, and `Appearance` distinct rather than presenting every
  customization as a generic filter.
- Backlog summarizes the number of active filter clauses and names a non-default
  due-date order separately. Task Ladder names the current metric, its Base/Now
  value mode when applicable, and its current direction. Mac adds `Custom row`
  when that workspace's independent Appearance differs from its default.
- iPhone shows Backlog and Task Ladder summaries in native navigation chrome;
  Main Task List retains its removable active-filter chips. Mac places the
  bounded summary inside the existing workspace-control toolbar action. No
  summary becomes a section or status strip inside an unbounded scrolling list.
- Activating a Backlog or Task Ladder summary opens the most relevant non-default
  control category. Main Task List's existing chips remain direct, individually
  removable filters; on Mac its toolbar summary opens the relevant control scope.
  The ordinary toolbar action still opens the workspace's primary category.
- Reset remains category-scoped. Mac Task Ladder now resets View, Sort, or
  Appearance independently, matching Mac Backlog and the iPhone View/Sort
  contract.
- Default state stays quiet. Summaries appear only while a control differs from
  its workspace default, and long combinations collapse to a bounded `+N` form.

## Consequences

- A person can explain why the current rows or order look different without
  reopening controls.
- The same terms mean the same thing on Mac and iPhone while each platform keeps
  native placement and its intentional feature differences.
- Backlog and Task Ladder retain content-first scrolling surfaces.
- Clearing one concern cannot silently erase unrelated sorting, view, or row
  appearance choices.
