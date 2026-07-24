# 0424: Make Task Detail Priority Optional

Status: Accepted

Date: 2026-07-24

Refines: [0100 Reveal Task Form Details by Section](0100-reveal-task-form-details-by-section.md), [0366 Keep Mac Task Detail Add More Inline](0366-keep-mac-task-detail-add-more-inline.md)

## Context

Task Details always showed the Priority matrix summary, including for tasks that retained the neutral default priority values. That gave an unset organizational field the same prominence as task details the user had deliberately added.

## Decision

iOS and macOS Task Details hide Priority when the task has the neutral defaults: no derived priority, medium importance, and medium urgency. Full Task Details offers Priority in Add More Details. Choosing it reveals and expands the matrix inline.

Priority remains visible whenever the task has a saved non-default priority, importance, or urgency value, including after reopening Task Details.

## Consequences

- New and otherwise neutral tasks have a simpler detail header.
- Users can add Priority without leaving Task Details.
- Existing customized priority metadata remains visible and editable.
