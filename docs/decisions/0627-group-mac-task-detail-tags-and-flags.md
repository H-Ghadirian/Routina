# 0627: Group Mac Task Detail Tags and Flags

## Status

Accepted

## Date

2026-08-21

## Refines

- [0497: Use Flags for Task Behavior Rules](0497-use-flags-for-task-behavior-rules.md)
- [0499: Explain Applied Flags in Task Details](0499-explain-applied-flags-in-task-details.md)
- [0188: Prefer Self-Explanatory UI Over Instructional Copy](0188-prefer-self-explanatory-ui-over-instructional-copy.md)

## Refined By

- [0628: Adapt Mac Task Detail Labels to Available Width](0628-adapt-mac-task-detail-labels-to-available-width.md)

## Context

Mac Task Details presented Tags and Flags in consecutive full-width cards. Both
are compact task labels, so the repeated background, border, and padding added
height and made related metadata feel more distant than it was. Removing their
visual distinction entirely would create a different problem because Tags are
organizational while Flags may change application behavior.

## Decision

Mac Task Details place assigned Tags and Flags inside one neutral metadata card.
Each concept retains its own visible heading and chip treatment, and a divider
separates the two rows when both are present. Flag chips keep their flag icon and
orange semantic accent; the shared container does not become an orange warning
surface. A task with only Tags or only Flags uses the same card without an empty
row or divider.

iOS already places both labeled groups inside the shared task header card and is
unchanged. Add Task, Edit Task, filtering, and Flag behavior are also unchanged.

## Consequences

- Task Details use less vertical space and present related label metadata as one
  scannable unit.
- Tags and Flags remain visibly and semantically distinct rather than becoming
  one interchangeable taxonomy.
- Future task-label metadata should prefer compact labeled groups inside the
  shared card when its meaning can remain clear without separate card chrome.
