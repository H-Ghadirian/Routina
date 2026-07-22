# 0404: Temporarily Expand Mac Sidebar During Search

## Status

Accepted

## Date

2026-07-18

## Refines

- [0310: Show Mac Home Toolbar Search](0310-show-mac-home-toolbar-search.md)
- [0343: Add Mac Home Sidebar Collapse Control](0343-add-mac-home-sidebar-collapse-control.md)
- [0389: Create Task From Mac Search Empty State](0389-create-task-from-mac-search-empty-state.md)

## Context

Mac Home search filters task-list and Timeline-style content from the toolbar, but matching task rows can still be hidden when the left sidebar column is collapsed or when task-list super sections and nested groups are collapsed. That makes search feel indirect because users may need to expand the sidebar, then expand `Future`, tag groups, or other subsections before seeing the result they asked for.

The existing sidebar collapse control remains useful outside search because it lets users reclaim workspace width and keep their preferred task-list outline density.

## Decision

When the Mac Home toolbar search query first becomes non-empty after trimming whitespace, Home captures the current left-sidebar presentation state: sidebar column visibility, daily routine section collapse state, `Today` daily inner-group collapse state, `Future` collapse state, archived collapse state, and the stored tag/custom/deadline subsection collapse IDs.

While that search session is active, Home temporarily reveals the left sidebar column and treats all task-list super sections and nested task-list groups as expanded so matching rows are visible without extra clicks. Clearing the search query restores the captured sidebar column visibility and task-list collapse state from the start of the search session, then rebuilds and resets the task-list scroll container to the top of the restored outline so a selected filtered result cannot keep the sidebar anchored to stale or hidden content. Home also suppresses collapse transitions during that restore so the expanded search layout cannot leave stretched section surfaces behind.

The temporary expansion is presentation state for search. It does not rewrite the user's saved collapse preferences as the mechanism for showing results, and it does not remove the explicit sidebar toggle from normal Home use.

## Consequences

- Search results in collapsed task-list areas become visible immediately.
- Users can search from a collapsed sidebar without losing their previous sidebar layout.
- Future Mac toolbar search work should preserve snapshot-and-restore behavior around any temporary result-reveal affordance.
