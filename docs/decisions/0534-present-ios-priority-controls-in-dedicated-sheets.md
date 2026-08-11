# 0534: Present iOS Priority Controls in Dedicated Sheets

## Status

Accepted

## Date

2026-08-11

## Refines

- [0462: Use a Compact Progressive iOS Task Editor](0462-use-a-compact-progressive-ios-task-editor.md)
- [0424: Make Task Detail Priority Optional](0424-make-task-detail-priority-optional.md)

## Context

The Importance and Urgency matrix has sixteen choices and axis labels. Keeping
it inline made iOS Add Task, Edit Task, and Filters substantially longer even
when a person only needed to see the current priority. It also made the
surrounding form or filter settings harder to scan.

## Decision

iOS Add Task and Edit Task show Priority as one compact row that names the
current derived priority. Tapping it opens a dedicated Priority sheet with the
existing Importance and Urgency matrix and its existing bindings.

iOS Home, Stats, and Timeline Filters likewise show a compact Filter priority
entry. Its sheet keeps the current threshold selection, the `Show all priority
levels` reset, and the same matching semantics as the former inline matrix.

This changes only presentation and disclosure. Importance, urgency, derived
priority, filter persistence, and task-list matching stay unchanged.

## Consequences

- Main forms and filters are shorter and easier to scan.
- The current task priority or active filter threshold stays visible before
  opening the picker.
- All sixteen choices and the all-levels reset remain one deliberate tap away.
