# 0652: Keep Effort Fields Independent and Disclosures Honest

## Status

Accepted

## Date

2026-08-24

## Refines

- [0188: Prefer Self-Explanatory UI Over Instructional Copy](0188-prefer-self-explanatory-ui-over-instructional-copy.md)
- [0366: Keep Mac Task Detail Add More Inline](0366-keep-mac-task-detail-add-more-inline.md)
- [0625: Group Task Detail Add Detail With Edit](0625-group-task-detail-add-detail-with-edit.md)
- [0651: Keep Task Focus Separate From Actual Time](0651-keep-task-focus-separate-from-actual-time.md)

## Context

Task Details presents Estimate, Actual time, Story points, and Focus near one
another, but each value has a separate meaning and persistence field. The Mac
`Add a detail` catalog previously hid `Estimate` when Story points existed or
Focus was enabled, even if the task still had no duration estimate. iOS did not
offer the missing Estimate action there at all.

An active task Focus session also forces its controls open so Pause, Finish,
and Abandon remain visible. The Effort and standalone Focus headers retained a
chevron and button hit area during that forced state even though the content
could not collapse, advertising an action that was unavailable.

## Decision

- `Estimate` appears in the iOS and full Mac Task Detail `Add a detail` chooser
  whenever `estimatedDurationMinutes` is missing. Actual time, Story points,
  and Focus-enabled state do not affect that eligibility.
- Selecting Estimate uses the established platform editing route: inline
  Estimation editing on Mac and the focused Estimation edit section on iOS.
- While an active task Focus session forces Effort or Focus content open, its
  header is static and shows no disclosure chevron. When forced expansion ends,
  the ordinary clickable disclosure header and chevron return.
- These presentation rules do not change task data, existing estimates, actual
  time, Story points, or Focus history.

## Consequences

- Enabling Focus or recording Story points can no longer strand a task without
  a discoverable way to add its duration estimate.
- The same missing Estimate action is available from Task Details on iOS and
  macOS.
- A visible chevron always corresponds to a working expand or collapse action.
- Active timer controls remain visible until the session ends without
  pretending that their forced-open container is collapsible.
