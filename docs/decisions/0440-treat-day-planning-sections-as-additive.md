# 0440 — Treat Day Planning Sections as Additive

Status: Accepted

Date: 2026-07-26

Refines: [0200 Support Task Planned Dates](0200-support-task-planned-dates.md), [0252 Stabilize Home Task List Presentation Identity](0252-stabilize-home-task-list-presentation-identity.md), [0350 Add Optional Mac Tomorrow Task Section](0350-add-optional-mac-tomorrow-task-section.md), [0394 Add Custom Mac Sidebar Task Sections](0394-add-custom-mac-sidebar-task-sections.md), [0400 Plan Tracking Rows Into Today](0400-plan-tracking-rows-into-today.md), [0411 Manage Custom Task Sections in Settings](0411-manage-custom-task-sections-in-settings.md)

## Context

Home previously treated planning as exclusive task-list classification. A task
shown in `Today` or enabled `Tomorrow` was claimed before normal grouping and
removed from `Future`; custom and pinned placement could prevent planning
placement entirely. Planning a custom-section task also erased its custom
assignment, while moving a planned task into a custom section erased its plan.

That made a date-only planning intention behave like a change in task identity
or organization. Users could not review the same task through both the day they
intend to do it and the durable section, tag, deadline, or pinned context where
it belongs.

## Decision

`Today` and `Tomorrow` are additive planning projections, not exclusive
organizational buckets.

An active task that qualifies for a visible planning day appears in that
planning section and also keeps its ordinary Home placement. Depending on its
state and settings, that placement may be Pinned, a custom section or
subsection, or the regular grouping presented inside `Future`. On iOS, a task
planned for today likewise remains in its ordinary task-list section.

Planning and custom assignment are independent stored dimensions. Setting or
clearing a planned date does not clear a custom-section assignment, and moving
a task into or out of a custom section does not clear its planned date.
Custom-section rules and manual assignments can therefore surface the same task
alongside its planning row.

Home still deduplicates repeated source data and claims each task exactly once
within the non-planning classification pipeline. It also deduplicates each
planning section independently. The same semantic task ID may intentionally
render once in a planning section and once in its organizational section;
section and group identities remain stable, and each copy uses the ordering
context of the section that contains it.

Archived, completed, canceled, filtered-out, and otherwise ineligible tasks
retain their existing planning visibility rules. The optional Mac `Tomorrow`
setting still controls whether that planning projection is shown.

## Consequences

- Planning a task no longer makes it disappear from its tag, deadline, custom,
  pinned, or Future context.
- Today/Tomorrow and ordinary sections can show two rows for one task by
  design, with both rows opening and mutating the same underlying task.
- Reordering a planning row changes only that planning section's manual order;
  reordering its ordinary row changes only its owning section's order.
- Features that count rendered rows must distinguish visible row count from
  unique task count.
- Planner day-agenda deduplication remains separate and unchanged.
