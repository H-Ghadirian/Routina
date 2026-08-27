# 0687: Reveal Backlog Tasks in Explicit Planner Search

## Status

Accepted

## Date

2026-08-27

## Revises

- [0546: Separate Mac Backlog From the Radar Sidebar](0546-separate-mac-backlog-from-the-radar-sidebar.md), for explicit search only
- [0591: Include Suppressed Mac Search Matches Beside Ordinary Results](0591-include-suppressed-mac-search-matches-beside-ordinary-results.md), by removing Backlog exclusion from the search fallback

## Refines

- [0418: Keep Whole-History Work Out of Scrolling Render Paths](0418-keep-whole-history-work-out-of-scrolling-render-paths.md)
- [0634: Unify Mac Workspace Search and Creation](0634-unify-mac-workspace-search-and-creation.md)

## Context

Backlog placement intentionally keeps deferred work out of the normal Mac task sidebar. The same exclusion also applied to Planner's explicit search fallback, so a person could search for an exact known task, see it in Backlog, and still receive no corresponding Planner result.

That treated deliberate retrieval like ordinary browsing. Backlog search already handles the reverse case by finding tasks outside Backlog and naming their real location. Keeping Backlog tasks undiscoverable from Planner made the shared search control feel incomplete and encouraged unnecessary movement or duplicate creation.

## Decision

A non-empty Mac Planner task search includes eligible tasks explicitly assigned to Backlog sections in its search-only fallback catalog. A matching task appears under `Search Results`, names its durable location as `Backlog › <section>` or `Backlog › <super section> › <subsection>`, opens normal Task Details, and does not offer the fallback row's inline completion action.

Backlog placement continues to exclude the task from ordinary unsearched sidebar placement. It also stays out of the unsearched `Hidden by flag` reveal path when it carries `Hide from Task Lists`; explicit Backlog placement remains the stronger browsing location. Clearing search restores the ordinary off-radar presentation without moving or changing the task.

The fallback continues to respect task-list mode, active filters, archived visibility, and stable task-ID deduplication. Search-source assembly, location lookup, filtering, grouping, counts, and row metadata remain part of the cached task-list presentation rebuild at data, organization, filter, or query invalidation boundaries. Scrolling rows consume the stored location title and do not scan the task or section catalog.

## Consequences

- Explicit search becomes a trustworthy retrieval action without weakening Backlog's quiet normal placement.
- Planner and Backlog search both identify cross-workspace matches instead of requiring a task move before it can be found.
- Search results communicate that the task remains in Backlog and never imply normal main-task-list membership.
- A Backlog task carrying `Hide from Task Lists` appears once in `Search Results`, not once there and again under `Hidden by flag`.
