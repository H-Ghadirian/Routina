# 0650: Use Done Label and Collapse Recorded-Completion Calendar List Sections

## Status

Accepted

## Date

2026-08-24

## Refines

- [0367: Show Day Agenda Done Sections](0367-show-day-agenda-done-sections.md)
- [0369: Show Day Task List Columns in Planner Calendar](0369-show-day-task-list-columns-in-planner-calendar.md)
- [0529: Collapse Calendar List Planned Task Sections](0529-collapse-calendar-list-planned-task-sections.md)
- [0551: Collapse Confirmed Assumed-Done Calendar List Sections](0551-collapse-confirmed-assumed-done-calendar-list-sections.md)
- [0418: Keep Whole-History Work Out of Scrolling Render Paths](0418-keep-whole-history-work-out-of-scrolling-render-paths.md)

## Context

Planner used the plural label `Dones` for the section containing recorded
completion activity even though the rest of Routina uses `Done` as the outcome
and action name. Mac Calendar `List` also left that section permanently
expanded while its other task sections could be collapsed independently. A
busy completion history could therefore dominate a day column and make the
comparison surface harder to scan.

## Decision

Planner labels recorded completion sections `Done` on every platform and uses
the same wording in user-facing help.

On macOS, each non-empty `Done` section in Calendar `List` is a full-width
disclosure with an independent per-day expansion choice. It uses the existing
Settings -> Calendar -> Calendar List `Collapsed` / `Expanded` default when a
day column is first shown, just like Planned tasks, Assumed done, and Confirmed
assumed done.

The focused right-side day-task sidebar remains expanded. Disclosure state
continues to control only row rendering after the cached day-task presentation
is available; it does not filter activity, change counts, mutate completion
history, or repeat Planner grouping during scrolling.

## Consequences

- Recorded completion wording matches Routina's established `Done` outcome.
- Dense completion history stays compact until the person chooses to inspect
  it, while the section count remains visible.
- Every Calendar List task section shares one stored default but keeps an
  independent local expansion choice for each visible day.
- The focused sidebar and Planner presentation-snapshot boundaries stay
  unchanged.
