# 0424: Make Task Detail Priority Optional

Status: Accepted

Date: 2026-07-24

Refines: [0100 Reveal Task Form Details by Section](0100-reveal-task-form-details-by-section.md), [0366 Keep Mac Task Detail Add More Inline](0366-keep-mac-task-detail-add-more-inline.md)

Refined by: [0625 Group Task Detail Add Detail With Edit](0625-group-task-detail-add-detail-with-edit.md), which moves the Priority entry point into the grouped header chooser.

## Context

Task Details always showed the Priority matrix summary, including for tasks that retained the neutral default priority values. That gave an unset organizational field the same prominence as task details the user had deliberately added.

## Decision

iOS and macOS Task Details hide Priority when the task has legacy neutral defaults: none or medium derived priority, medium importance, and medium urgency, unless the task records that the user explicitly revealed Priority. Full Task Details offers Priority in Add More Details. Choosing it reveals and expands the matrix inline and persists that choice for the task.

Priority remains visible whenever the task has a saved non-neutral priority, importance, or urgency value, or the explicit per-task visibility preference, including after reopening Task Details. Quick Add sets that preference when the user enters priority syntax, including `!medium`.

## Consequences

- New and otherwise neutral tasks have a simpler detail header.
- Users can add Priority without leaving Task Details.
- Existing customized priority metadata remains visible and editable.
- Legacy tasks whose only priority metadata is the old implicit Medium/Medium default stay hidden, matching Edit Task.
