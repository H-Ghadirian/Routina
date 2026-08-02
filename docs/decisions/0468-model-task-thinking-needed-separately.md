# 0468: Model Task Thinking Needed Separately

Status: Accepted

Date: 2026-08-02

Refines: [0058 Use Progressive Task Forms](0058-use-progressive-task-forms.md), [0366 Keep Mac Task Detail Add More Inline](0366-keep-mac-task-detail-add-more-inline.md), [0391 Filter Task List by Duration Estimates](0391-filter-task-list-by-duration-estimates.md), [0424 Make Task Detail Priority Optional](0424-make-task-detail-priority-optional.md), and [0462 Use a Compact Progressive iOS Task Editor](0462-use-a-compact-progressive-ios-task-editor.md)

## Context

Duration does not describe how hard a task is to begin or perform. Cleaning may take an hour while requiring little interpretation, concentration, or decision-making; a five-minute legal call or work reply may demand much more mental effort and be easier to procrastinate on. Pressure and priority also describe different concerns: pressure is the felt urgency around a task, while priority and importance/urgency describe why it should be selected.

Using one of those existing fields as a proxy for mental complexity would make task planning misleading and prevent users from finding work that fits their available cognitive energy.

## Decision

Tasks store an independent `Thinking needed` level with `None`, `Low`, `Medium`, and `High` values. The field describes the understanding, concentration, or decision-making the task requires; it does not measure duration, emotional pressure, importance, urgency, or priority.

Add Task and Edit Task expose the field as a progressive optional detail on iOS and macOS. Task Details shows a saved non-`None` value and lets users add or change the field directly. Home task filters offer exact `All`, `None`, `Low`, `Medium`, and `High` matching on both platforms and preserve the selection with each task-list mode's filter state.

The value participates in task copying, sharing, CloudKit direct-pull repair, backup/import, and cloud-usage estimates. Existing tasks and older payloads default to `None`.

Thinking needed is descriptive metadata only. It must not automatically change scheduling, pressure, importance, urgency, priority, estimates, or task ordering.

## Consequences

- Users can distinguish long, mechanically easy work from brief, cognitively demanding work.
- Energy-aware task selection can use an explicit filter without overloading pressure or time estimates.
- New automation or sorting based on thinking needed requires a separate product decision; this record adds metadata and filtering only.
- Compatibility paths must continue treating a missing or unknown value as `None`.
