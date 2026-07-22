# 0405: Show Hidden Scheduled Task Search Results

## Status

Accepted

## Date

2026-07-18

## Refines

- [0310: Show Mac Home Toolbar Search](0310-show-mac-home-toolbar-search.md)
- [0387: Keep Completed Scheduled Blocks Visible](0387-keep-completed-scheduled-blocks-visible.md)
- [0389: Create Task From Mac Search Empty State](0389-create-task-from-mac-search-empty-state.md)
- [0404: Temporarily Expand Mac Sidebar During Search](0404-temporarily-expand-mac-sidebar-during-search.md)

## Context

Mac toolbar search filters both the Home task-list sidebar and task-backed Planner Calendar presentation. Calendar `Schedule` intentionally keeps completed scheduled task blocks visible, so a query can visibly match a calendar block while the normal Home task-list sections hide the same task because it is already done, completed, canceled, or otherwise outside active sidebar placement.

Showing the sidebar no-results state in that case makes search feel inconsistent: the main calendar proves the query matched a task, but the left task list gives the user no row to select.

## Decision

When a non-empty Mac toolbar search leaves the normal task-list sidebar presentation empty, Home may replace the empty state with a search-only `Search Results` section built from known task display snapshots that match the same query and active task filters.

This fallback is presentation-only. It does not change normal task-list section membership, daily done hiding, completed one-off handling, archived preferences, Planner block storage, or calendar search filtering. It also does not offer Mark Done actions from the fallback section, because these rows are often already resolved or outside active planning placement.

## Consequences

- Search no longer shows a matching task-backed Planner Calendar block while the left sidebar says there are no matching tasks.
- Completed scheduled rows remain visible for selection during search without becoming normal active sidebar rows.
- Future Mac search changes should keep empty-state creation guarded behind true no-result searches, including task rows that are only available through this search fallback.
