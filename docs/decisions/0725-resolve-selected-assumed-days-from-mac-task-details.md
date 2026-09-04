# 0725: Resolve Selected Assumed Days From Mac Task Details

## Status

Accepted

## Date

2026-09-04

## Refines

- [0370: Confirm Assumed-Done Rows Inline](0370-confirm-assumed-done-rows-inline.md)
- [0521: Group Secondary Mac Task Detail Actions](0521-group-secondary-mac-task-detail-actions.md)
- [0626: Join Mac Task Detail Completion and Overflow](0626-join-mac-task-detail-completion-and-overflow.md)

## Revised By

- [0726: Keep Selected Assumed-Day Confirmation Primary](0726-keep-selected-assumed-day-confirmation-primary.md)

## Context

Mac Task Details lets a person select one assumed calendar day and confirm that
specific date with the prominent completion action. Rejecting the same assumption
was available from Home and Planner rows, but not from the selected task-detail
context. The person had to leave the task even though the selected day already made
the intended occurrence unambiguous.

The existing joined completion and overflow control already groups the primary
positive outcome with secondary lifecycle choices. Rejecting the selected
assumption belongs there without competing visually with confirmation.

## Decision

When the selected calendar date in full Mac Task Details is an unresolved assumed
day, the adjacent `⋮` menu begins with `Missed` and separates that outcome from
Pause, Pause Until, Archive, Restore, cancellation, and deletion actions.

Choosing `Missed` records a missed log using the selected assumed day's normal
assumption timestamp. It resolves only that date, creates no completion, leaves
other assumed dates unchanged, and remains correctable through task history. The
item is absent when the selected date is not currently assumed done.

The direct green action remains confirmation, Delete remains the only red
destructive menu item, and the compact Mac companion pane and iOS controls remain
unchanged.

## Consequences

- A selected assumed day can be confirmed or rejected without leaving Task Details.
- Both alternatives target the date already named by the primary action and calendar
  selection.
- Bulk confirmation remains deliberate and does not affect the selected-day Missed
  action.
- Missed history stays separate from completed and canceled history.
