# 0389 Create Task From Mac Search Empty State

Status: Accepted

Date: 2026-07-13

Refines: [0315 Merge Mac Quick Add Into Toolbar Search](0315-merge-mac-quick-add-into-toolbar-search.md), [0378 Open Mac Add Task From Toolbar Search With Command Return](0378-open-mac-add-task-from-toolbar-search-command-return.md)

## Context

Mac toolbar search already treats a no-results query as creation intent: Return can quick-create a task, and Command-Return opens the full Add Task form with the query seeded into the Identity task-name field.

When the same query leaves both the task-list sidebar and Planner Timeline surface empty, the sidebar previously showed older filter-focused copy and did not expose the richer Add Task path. That made the left and main empty states disagree even though they were responding to one shared search query.

## Decision

For a non-empty Mac Home toolbar search query with no matching task or Timeline-style result, the task-list sidebar empty state uses the same no-results subtext as the Planner Timeline surface: `Try a different timeline search or filters.`

That empty state also shows a `Create task` button. Pressing it opens the full Mac Add Task form through the same seeded route as Command-Return, using the trimmed search query as the Identity task-name field, dismissing toolbar search focus, and clearing the search text.

The button follows the existing no-results guard: it appears only when the query is eligible for search creation and has no matching task or timeline result.

## Consequences

The no-results search surface now offers both recovery paths in context: adjust the search/filters or create the missing task.

The sidebar and main Planner Timeline empty states stay visually and semantically aligned for shared global search.

Future Mac search empty-state affordances should continue to reuse the toolbar search creation guard so visible matches do not encourage duplicate task creation.
