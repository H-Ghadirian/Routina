# 0674: Hide Flagged Tasks From Calendar List

## Status

Accepted

## Date

2026-08-27

## Revises

- [0636: Replace Configurable Flags With Built-In Behaviors](0636-replace-configurable-flags-with-built-in-behaviors.md)

## Refines

- [0369: Show Day Task List Columns in Planner Calendar](0369-show-day-task-list-columns-in-planner-calendar.md)
- [0418: Keep Whole-History Work Out of Scrolling Render Paths](0418-keep-whole-history-work-out-of-scrolling-render-paths.md)
- [0530: Separate Confirmed Assumed Dones in Calendar List](0530-separate-confirmed-assumed-dones-in-calendar-list.md)
- [0637: Search Settings by Destination](0637-search-settings-by-destination.md)
- [0650: Use Done Label and Collapse Recorded-Completion Calendar List Sections](0650-use-done-label-and-collapse-recorded-completion-calendar-list-sections.md)

## Context

Some repeating or tracking tasks create useful Planner and completion evidence
but make the side-by-side Calendar `List` noisy. In particular, automatically
assumed work can fill the `Assumed done` section even when the person does not
need that task in this comparison surface. Removing the task, its assumption,
or its Planner evidence would make other views less truthful.

Routina's fixed built-in Flags already express independent surface behavior.
The existing four-Flag catalog deliberately requires a new product decision
before another behavior is added.

## Decision

Routina adds a fifth built-in behavior Flag, `Hide from Calendar List`. A task
carrying it is omitted from the per-day columns in Mac Planner Calendar
`List`, including `Planned tasks`, `Assumed done`, `Confirmed assumed done`,
and `Done`. The hidden task does not contribute to those section counts.

The Flag affects only the Calendar `List` columns. Calendar `Schedule` blocks,
the Schedule day-header count and focused day-task sidebar, Planner Timeline,
Home task lists, Task Ladder, Stats, task history, assumptions, completion
records, and task storage remain unchanged. A person can therefore recover and
inspect the task through the ordinary task, Schedule, sidebar, and history
routes without clearing the Flag.

The canonical built-in catalog expands from four to five values. Launch repairs
the catalog without scanning or rewriting task assignments, and existing Flag
string/rule persistence continues to carry the new kind through sync and
backup.

Calendar List exclusion membership is derived with the existing cached
Calendar task-filter snapshot. Per-day List presentation includes the excluded
task IDs in its cache identity, while the focused sidebar requests the same
cached presentation without that exclusion. Task Flag storage participates in
the Planner data-revision signature so an edit invalidates the presentation
once instead of introducing task scans or filtering in scrolling row builders.

## Consequences

- Automatically assumed tracking work can stay out of Calendar List without
  losing its assumption or completion evidence.
- All four task-backed Calendar List sections follow one consistent task-level
  visibility choice.
- Calendar Schedule and the focused day sidebar remain reliable recovery paths.
- The fifth Flag appears in Settings and Add/Edit Task on both platforms, while
  its visible effect currently belongs to the Mac Calendar List surface.
- Calendar List keeps its cached presentation and scrolling-performance
  boundaries.
