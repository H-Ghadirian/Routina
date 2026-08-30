# 0699: Offer Task Creation From Empty iOS Focus

## Status

Accepted

## Date

2026-08-30

## Refines

- [0264: Match Button Hit Areas to Visual Surfaces](0264-match-button-hit-areas-to-visual-surfaces.md)
- [0539: Offer iOS Task Creation From Home Empty States](0539-offer-ios-task-creation-from-home-empty-states.md)
- [0695: Promote Stats and Settings in iOS Navigation](0695-promote-stats-and-settings-in-ios-navigation.md)
- [0698: Focus First iOS Home on the First Task](0698-focus-first-ios-home-on-the-first-task.md)

## Context

The global iOS New chooser keeps Focus available before a person has created a
task. Opening Focus with no eligible active tasks previously produced a passive
message explaining that a task was required. That explanation identified the
problem but left the person to dismiss Focus, reopen New, and find Create Task.

The empty state should preserve the predictable New chooser while providing a
direct recovery path at the point where the missing prerequisite becomes clear.

## Decision

When the iOS Focus picker has no eligible active tasks, its Task section shows
one full-row `Create Task` action with a short explanation that an active task is
required. The complete visible row is tappable.

Selecting the row dismisses Focus before opening the existing Smart Add task
flow through Home. Routina does not stack two competing sheets or introduce a
second task-creation implementation. Canceling creation follows the normal Smart
Add dismissal path; the person can reopen Focus after creating a task.

Search- or tag-filtered empty results remain informational because eligible
tasks still exist and changing the query or tag resolves those states.

## Consequences

- Focus remains a stable global New action even when the task catalog is empty.
- The empty picker becomes actionable without duplicating Smart Add.
- Sheet dismissal completes before task creation begins, avoiding competing
  presentations.
- Filtered no-result states do not misleadingly suggest creating another task.
