# 0664: Open iOS Workspaces From the Home List

## Status

Accepted

## Date

2026-08-26

## Revises

- [0546: Separate Mac Backlog From the Radar Sidebar](0546-separate-mac-backlog-from-the-radar-sidebar.md), for platform availability
- [0561: Add a Separate Mac Task-Ranking Ladder](0561-add-separate-mac-task-ranking-ladder.md), for platform availability
- [0574: Separate Task Ladder Placement From Completion](0574-separate-task-ladder-placement-from-completion.md), which previously kept Task Ladder group navigation on Mac only

## Refines

- [0033: Use an App-Owned iOS More Tab](0033-use-app-owned-ios-more-tab.md)
- [0418: Keep Whole-History Work Out of Scrolling Render Paths](0418-keep-whole-history-work-out-of-scrolling-render-paths.md)
- [0543: Defer iOS Sync Refresh Work Until Its Tab Is Active](0543-defer-ios-sync-refresh-work-until-its-tab-is-active.md)

## Context

Backlog, Timeline, and Task Ladder answer different review questions, but compact
iOS navigation deliberately limits the bottom bar to five stable items. Timeline
already had a tab, while Backlog and Task Ladder were complete only as Mac
workspaces. A person who starts from Home needed one predictable place to find
all three without changing the tab bar or adding another global drawer.

The complete Backlog and Task Ladder presentations can scale with the full task
catalog. Adding links must not make the ordinary Home scrolling path build those
presentations or introduce a second navigation stack inside Home.

## Decision

The iOS Home task list ends with three native navigation rows in this order:
Backlog, Timeline, and Task Ladder. The rows appear only in Home, not in the
dedicated Search tab, and remain reachable beneath the task-creation empty state
when Home has no tasks. This decision does not change the iOS tab bar.
[0698](0698-focus-first-ios-home-on-the-first-task.md) later hides all three
rows only during a new installation's focused first-task experience; an
established empty Home continues to show them.

Each row opens its destination through Home's existing navigation hierarchy.
The Home-launched Timeline reuses the Timeline surface without installing its
own compact `NavigationStack` or iPad split hierarchy inside Home.

Backlog and Task Ladder use the same platform-neutral reducers, persisted
organization, Flag rules, and stable presentation snapshots as macOS. Their
iOS views are native lists:

- Backlog supports local search, durable super-section and subsection
  disclosure, empty catalog sections, hidden-by-Flag tasks, outside results,
  Task Details, and moving an explicitly backlogged task back to Home.
- Task Ladder supports metric and Base/Now selection, direction, scoped inner
  ladders, search, task and container details, linked-task suggestions, and
  manual move commands where the metric permits them.

Mac keeps its full-workspace layouts and broader creation and organization
controls. The iOS surfaces consume feature-owned snapshots and do not derive the
full Backlog or Task Ladder from Home's `List` body.

## Consequences

- Home becomes the stable iOS entry point for organization and history
  workspaces without displacing Search, New, Timeline, or More in this step.
- Backlog and Task Ladder data, eligibility, ranking, and group semantics stay
  consistent across iOS and macOS.
- The three rows remain useful on an established empty Home rather than
  disappearing with task content; first-task guidance temporarily omits them.
- Search results stay focused on tasks and do not repeat workspace navigation.
- Future tab-bar changes remain a separate product decision.
