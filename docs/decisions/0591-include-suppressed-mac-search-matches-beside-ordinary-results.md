# 0591: Include Suppressed Mac Search Matches Beside Ordinary Results

## Status

Accepted

## Date

2026-08-16

## Refines

- [0310: Show Mac Home Toolbar Search](0310-show-mac-home-toolbar-search.md)
- [0405: Show Hidden Scheduled Task Search Results](0405-show-hidden-scheduled-task-search-results.md)
- [0418: Keep Whole-History Work Out of Scrolling Render Paths](0418-keep-whole-history-work-out-of-scrolling-render-paths.md)

## Context

Mac toolbar search built the ordinary task-list sections first and consulted the
search-only fallback catalog only when those sections had no rows. A broad query
could therefore match both ordinarily placed tasks and an older completed or
otherwise placement-suppressed task while showing only the ordinary rows. Adding
another character could remove the ordinary matches, activate the fallback, and
make the suppressed task suddenly appear even though it also matched the broader
query.

That made search refinement behave backwards and prevented a person from
trusting a broad query as a complete view of its eligible task matches.

## Decision

For every non-empty Mac toolbar task search, Home appends a search-only
`Search Results` section when the eligible fallback catalog contains matching
task rows that are not already present in ordinary or Flag-reveal sections.
Ordinary section placement remains unchanged, and stable task IDs prevent a
task from appearing twice.

The fallback continues to respect the active task-list mode, filters, Backlog
exclusion, and archived-task visibility. Its work remains part of the cached
search presentation rebuild at query invalidation boundaries rather than the
scrolling render path. Search-only rows continue to omit Mark Done actions.

## Consequences

- A broad query includes eligible suppressed matches even when it also has
  ordinary task-list results.
- Refining a query cannot reveal a matching fallback task solely because other
  results disappeared.
- Clearing search still restores normal task-list placement without moving or
  changing any task.
