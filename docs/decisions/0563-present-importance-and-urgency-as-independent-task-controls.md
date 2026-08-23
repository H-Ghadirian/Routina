# 0563: Present Importance and Urgency as Independent Task Controls

## Status

Accepted

## Date

2026-08-13

## Refines

[0424 Make Task Detail Priority Optional](superseded/0424-make-task-detail-priority-optional.md)
and [0534 Present iOS Priority Controls in Dedicated Sheets](0534-present-ios-priority-controls-in-dedicated-sheets.md)

## Context

The shared Importance and Urgency matrix made two different judgments appear as
one priority decision. Its sixteen-cell interaction was also visually unlike
the independent Pressure and Thinking needed controls that describe adjacent
task metadata. In Task Details, adding the old Priority control marked both
fields explicit even when a person only intended to decide one of them.

## Decision

Task Add and Edit present Importance and Urgency as independent four-level
segmented controls, using the same visual control family as Pressure and
Thinking needed. Each field has its own label and explanation: Importance is
how much a task matters to goals and commitments, while Urgency is how soon it
needs attention.

Task Details also reveals and persists Importance and Urgency independently.
iOS presents each as its own compact picker pill, matching Pressure and
Thinking needed. macOS presents each as its own colored segmented header box,
alongside those existing controls. Adding one field marks only that field
explicit; legacy saved priority visibility continues to make both fields
available for compatibility.

Derived Priority remains a stored, recalculated sorting value, but is no
longer presented as a separate task-editing control or summary. Home, Stats,
and Timeline filters retain their matrix because a filter cell deliberately
expresses the combined minimum threshold for both fields.

## Consequences

- People can distinguish a task's strategic importance from its time pressure
  without translating a matrix position.
- Selecting or revealing one field does not silently complete the other
  field's metadata.
- Existing priority-based sorting, Quick Add compatibility, and combined
  threshold filtering retain their current semantics.
