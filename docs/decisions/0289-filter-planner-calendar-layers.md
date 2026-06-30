# 0289: Filter Planner Calendar Layers

Status: Accepted
Date: 2026-06-27

Refined by: [0319: Open Planner Filters in the Home Filter Pane](0319-open-planner-filters-in-home-filter-pane.md)

## Context

The Planner calendar combines several visible layers: timed planned task blocks, all-day task and event pills, automatic timeline suggestions, standalone events, Focus, Away, and Sleep. Users sometimes need to temporarily reduce visual density without changing task, event, session, or planner-block data.

Recent Planner decisions established the right-side Planner sidebar as the stable surface for secondary Planner content. Calendar filters should reuse that surface rather than adding another floating panel or modal sheet.

## Decision

Planner exposes a compact filter button in the Planner header. Pressing it opens the existing right-side Planner sidebar with presentation-only calendar layer toggles.

The filter sidebar can show or hide timed planned tasks, all-day tasks, timeline suggestions, events, Focus, Away when Away is enabled, and Sleep. These filters affect the rendered calendar layers and planned-task agenda counts/lists for the currently visible Planner UI, but they do not delete, reschedule, or otherwise mutate underlying records.

Only one Planner right-sidebar mode is open at a time. Opening filters clears slot-action and day-task-list sidebar presentation, while opening either of those Planner sidebars closes filters.

## Consequences

- Planner calendar filtering is local presentation state, not persisted task or calendar state.
- Hiding timeline suggestions also returns the calendar to badge-style access for timeline tasks on each day.
- Drop validation and protected-session blocking continue to use the underlying Planner model even when a visual layer is hidden.
