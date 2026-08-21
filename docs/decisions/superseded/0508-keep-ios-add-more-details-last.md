# 0508: Keep iOS Add More Details Last

Status: Superseded by [0625 Group Task Detail Add Detail With Edit](../0625-group-task-detail-add-detail-with-edit.md)

Date: 2026-08-08

Refines: [0188 Prefer Self-Explanatory UI Over Instructional Copy](../0188-prefer-self-explanatory-ui-over-instructional-copy.md) and [0425 Make Task Detail History Optional](../0425-make-task-detail-history-optional.md)

## Context

`Add more details` is a progressive-disclosure entry point, not part of a task's active workflow. When it appeared between the primary task controls and already visible contextual sections, it broke the detail surface into two unrelated regions and could appear immediately before Linked Tasks.

## Decision

On iOS, `Add more details` is always the last Task Detail section for both todos and routines. Comments, history, checklist items, linked events, linked tasks, and task extras render before it whenever visible.

Choosing an action from the disclosure retains its existing behavior; this decision changes presentation order only.

## Consequences

- The active task content reads continuously from current state through related context.
- The progressive disclosure has one stable, predictable location at the end of the page.
- Future iOS Task Detail sections must be inserted before `Add more details` unless they are themselves part of that disclosure.
