# 0509: Collapse Calendar List Assumed-Done Sections

Status: Accepted

Date: 2026-08-08

Refines: [0368 Hide Assumed-Done Calendar Layer by Default](0368-hide-assumed-done-calendar-layer-by-default.md), [0369 Show Day Task List Columns in Planner Calendar](0369-show-day-task-list-columns-in-planner-calendar.md), [0455 Customize Calendar List Task Rows](0455-customize-calendar-list-task-rows.md), and [0418 Keep Whole-History Work Out of Scrolling Render Paths](0418-keep-whole-history-work-out-of-scrolling-render-paths.md)

## Context

Calendar `List` is a compact comparison surface. A day can have many synthetic assumed-done rows, and expanding them automatically can push planned and recorded work out of view even though those rows are only provisional activity.

Assumed-done activity must remain reviewable and actionable, but its visual expansion should be a presentation concern. It must not alter the underlying day-task snapshot or repeat Planner history work while the columns scroll.

## Decision

On macOS, each non-empty `Assumed done` section in Calendar `List` has a full-width disclosure header that keeps its title and count visible. It is collapsed by default, and selecting its header expands or collapses only that day's section. The setting in Settings -> Calendar -> Calendar List lets the person choose `Collapsed` or `Expanded` as the default for newly shown Calendar List day columns.

The preference defaults to `Collapsed`, is mirrored with user preferences, and is included in backup/import. An explicit disclosure choice for an already visible day overrides the default for that view; changing the setting does not unexpectedly undo that in-progress review choice.

The right-side day-task sidebar remains unchanged. Collapsing only controls row rendering after the existing cached day-task presentation is available; it does not filter data, alter counts, hide synthetic activity globally, mutate completion history, or re-run Planner grouping during scrolling.

## Consequences

- Calendar List opens with a quieter, more scannable summary while retaining one-click access to each day’s assumptions.
- People who routinely audit automatic activity can opt into initially expanded sections.
- The persisted preference moves with normal user-preference backup/import without changing Planner records.
- The existing snapshot and list virtualization boundaries remain intact.
