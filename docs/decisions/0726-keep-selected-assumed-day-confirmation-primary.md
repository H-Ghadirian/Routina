# 0726: Keep Selected Assumed-Day Confirmation Primary

## Status

Accepted

## Date

2026-09-04

## Revises

- [0725: Resolve Selected Assumed Days From Mac Task Details](0725-resolve-selected-assumed-days-from-mac-task-details.md)

## Refines

- [0626: Join Mac Task Detail Completion and Overflow](0626-join-mac-task-detail-completion-and-overflow.md)

## Context

Task Details promoted `Confirm N assumed days` into the prominent completion
segment when Today was selected and older assumed dates existed. That made a
calendar selection which visibly named one day trigger a bulk mutation across
many dates. A large accumulated count made the mismatch particularly risky.

The selected date should determine the primary Task Detail action. Bulk review
remains useful, but its broader scope needs secondary placement and an explicit
count.

## Decision

When an assumed date is selected in Task Details, the primary completion action
always targets only that date. Today uses `Confirm done`; a past selected date uses
`Confirm for <date>`.

For eligible tasks with older unresolved assumptions, full Mac Task Details puts
the counted `Confirm N assumed days` action in the adjacent `⋮` menu. When the
selected date is also assumed done, `Missed` remains first, bulk confirmation
follows it, and a separator keeps both assumption-resolution choices apart from
Pause, Pause Until, Archive, Restore, cancellation, and deletion.

The existing secondary bulk-confirm control on other supported Task Detail layouts
remains secondary. Rolling interval tasks that require individual confirmation do
not expose bulk confirmation.

## Consequences

- Selecting Today can never silently expand a one-day confirmation into many days.
- The prominent action and calendar selection share one scope.
- Bulk confirmation remains available with its affected-day count, but requires a
  deliberate secondary choice.
- Missed and bulk confirmation stay grouped as assumption-review actions without
  competing with the primary selected-day confirmation.
