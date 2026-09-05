# 0739: Preserve iOS Assumed Completion Transition Geometry

## Status

Accepted

## Date

2026-09-05

## Refines

- [0188: Prefer Self-Explanatory UI Over Instructional Copy](0188-prefer-self-explanatory-ui-over-instructional-copy.md)
- [0594: Simplify iOS Task Detail Scan and Action Hierarchy](0594-simplify-ios-task-detail-scan-and-action-hierarchy.md)
- [0595: Keep Task Completion Colors Consistent Across Platforms](0595-keep-task-completion-colors-consistent-across-platforms.md)
- [0643: Join iOS Task Detail Completion and Routine Actions](0643-join-ios-task-detail-completion-and-routine-actions.md)

## Context

Confirming an assumed day changes several correct pieces of Task Detail data at
once: the assumed marker disappears, Status becomes completed, the due date can
advance, Completed increases, and the remaining assumed-day count decreases. The
assumed marker was conditional, and `Assumed done today` could wrap to two lines
where `Done today` needed one. Removing both heights above the pressed lifecycle
control shifted the visible page upward. The completion label also changed from a
text-only control to an icon-and-text Undo control, which exposed blank and
disabled-looking intermediate frames during the update.

## Decision

On iOS Task Details:

- confirming the selected assumed day creates a presentation-only acknowledgement
  for that day in the open Task Detail session;
- the existing `Assumed done` pill changes in place to `Confirmed` while that
  acknowledgement is relevant and Undo remains available;
- the Status card retains the height of its pre-confirmation value during that
  acknowledgement by measuring an accessibility-hidden copy of the old value;
- reopening Task Details starts from the ordinary persisted completed state, so
  the transition does not impose permanent empty space;
- enabled completion-creating actions and Undo share a stable icon-and-text label
  structure, changing from a checkmark to the Undo arrow without removing the
  label view; and
- custom symbol and text animation is omitted when Reduce Motion is enabled.

The transition reserves only the geometry that actually changed. It does not
apply a permanent minimum height to every routine, counter-scroll the page, or
persist visual acknowledgement state with the task.

## Consequences

- The task data can update immediately without moving the content or lifecycle
  control the person was viewing.
- The status treatment acknowledges the completed action before Task Detail is
  dismissed or reopened.
- Dynamic Type determines the reserved height from the real previous text rather
  than a fixed point value.
- Undo continues to use the established orange semantic cue and full joined hit
  target.
