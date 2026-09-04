# 0722: Move Mac Task Ladder Controls to the Right Sidebar

## Status

Accepted

## Date

2026-09-04

## Supersedes

- [0666: Keep Mac Task Ladder Chrome Context-Specific](superseded/0666-keep-mac-task-ladder-chrome-context-specific.md)

## Revises

- [0690: Place Mac Filters Beside Planner and Backlog Workspaces](0690-place-mac-filters-beside-planner-and-backlog-workspaces.md)

## Refines

- [0210: Store Durable Preferences in SwiftData](0210-store-durable-preferences-in-swiftdata.md)
- [0254: Move Mac Task Row Appearance to Home Filter Detail](0254-move-mac-task-row-appearance-to-home-filter-detail.md)
- [0316: Present Mac Home Filters as a Companion Pane](0316-present-mac-home-filters-as-companion-pane.md)
- [0418: Keep Whole-History Work Out of Scrolling Render Paths](0418-keep-whole-history-work-out-of-scrolling-render-paths.md)
- [0561: Add a Separate Mac Task-Ranking Ladder](0561-add-separate-mac-task-ranking-ladder.md)
- [0632: Integrate Mac Workspaces in the Main Window](0632-integrate-mac-workspaces-in-the-main-window.md)

## Context

Task Ladder kept metric, Base/Now, direction, count, group creation, and refresh in a compact bar above the ranked list. Planner and Backlog had since established one consistent top-toolbar entry for right-side companion controls, including a fullscreen form when more room was useful. Keeping every Ladder choice permanently above the list spent horizontal and vertical space, made Task Ladder the exception among primary workspaces, and left its row density fixed while Backlog and the Main Task List could be customized.

Task Ladder is an unbounded scrolling surface. Richer row choices must not cause schedule, status, progress, checklist, or other model derivation to run from lazy row builders.

## Decision

- The Mac top toolbar shows the same workspace-control entry immediately left of the combined workspace menu while Task Ladder is active. It opens a right companion pane, can expand fullscreen, and supports minimize and close using the established workspace-control presentation.
- Task Ladder removes its dedicated top control bar. Root value sections begin directly below the shared app toolbar; nested ladders retain their local back-and-group-title row.
- The Task Ladder control surface separates `View`, `Sort`, and `Appearance`. `View` owns the metric and optional Base/Now choice. `Sort` owns the selected metric's direction. `View` also keeps `Add Group` and explicit refresh as workspace actions.
- The current item or search-match count appears in the control-surface header. It is status, not a row inside the ranked list.
- `Appearance` owns an independent durable Task Ladder row preference. It can show or hide Icon, Row Color, Color Badge, Row Number, Repeating Badge, Status Badge, Schedule and Due Dates, Pressure, Progress, Steps and Checklist, Tags, and Flags. Places appears only when available; Goals is absent from this surface.
- The initial Task Ladder appearance preserves its existing sparse context: multiline titles, Icon, Repeating Badge, and Tags are shown. Group kind, inherited value, temporal change timing, child count, inner-ladder disclosure, and manual move controls remain structural Ladder context rather than optional appearance fields.
- The Task Ladder presentation snapshot precomputes reusable row appearance metadata and logical row numbers when its existing task, metric, direction, value mode, organization, Flag, or temporal inputs invalidate the snapshot. Lazy row builders only select cached values.
- The serialized Task Ladder row preference is mirrored through `RoutinaUserPreferences` and included in backup and restore independently from Main Task List and Backlog appearance.

## Consequences

- Task Ladder gains the same predictable right-side control location as Planner and Backlog and no longer reserves a permanent list-level control bar.
- View, ordering, group actions, refresh, count, and row appearance are available together without conflating Task Ladder with task filtering.
- People can tune Ladder row density without changing Main Task List or Backlog rows.
- Nested navigation remains visible where it is needed, while root list space is dedicated to ranked sections.
- Rich row options preserve the existing cached render-path boundary.
