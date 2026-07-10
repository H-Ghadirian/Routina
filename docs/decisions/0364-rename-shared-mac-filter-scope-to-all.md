# 0364: Rename Shared Mac Filter Scope to All

Date: 2026-07-10

Status: Accepted

Refines: [0319 Open Planner Filters in the Home Filter Pane](0319-open-planner-filters-in-home-filter-pane.md)

## Context

Decision [0319](0319-open-planner-filters-in-home-filter-pane.md) named the shared Mac Home filter scope `Both` when shared filters applied to Task List and Timeline. The shared tag and importance/urgency filters now also affect task-backed Planner Calendar items, so `Both` no longer accurately describes the scope.

## Decision

Mac Home labels the shared filter scope `All` in the companion pane scope picker.

The underlying scope continues to own shared tag and importance/urgency filters for Task List, Timeline, and task-backed Planner Calendar filtering. Task List, Timeline, and Calendar keep their dedicated scope labels and existing semantics.

## Consequences

- The scope picker now reads `All` / `Task List` / `Timeline` / `Calendar`.
- The label matches the three surfaces covered by the shared filters.
- Existing internal state can keep using the established shared-scope identity.
