# 0259: Allow Daily Checklist Auto-Assumed Completion

## Status

Accepted

## Date

2026-06-20

## Supersedes

[0255](superseded/0255-allow-gentle-auto-assumed-daily-completion.md)

## Refined by

[0398: Move Auto-Assume Done to Tracking](0398-move-auto-assume-done-to-tracking.md)

## Refines

- [0249: Reset Daily Checklist Progress Each Day](0249-reset-daily-checklist-progress.md)
- [0253: Guard Checklist Detail Mutations Through Reloads](0253-guard-checklist-detail-mutations-through-reloads.md)

## Context

Auto-assumed daily completion lets a routine default to done after its daily availability starts, while still allowing the user to confirm assumed days or mark a day as not done later.

Decision 0255 limited this option to simple daily Standard routines and excluded checklist routines. Daily checklist-completion routines now have day-scoped partial progress from decision 0249, so tomorrow's checklist starts unchecked even when today's routine was completed. That makes a day-level assumed completion compatible with checklist UI as long as assumption does not pretend individual checklist items were checked.

Checklist runout routines remain different: their actions are item-scoped, each item can have its own due date, and a routine completion is recorded only when all currently due runout items are reset together.

## Decision

Auto-assume done is available, opt-in, for:

- Daily Standard routines in Due and Gentle styles when they have no sequential steps and no checklist items.
- Daily Checklist-completion routines in Due and Gentle styles when they have at least one checklist item and no sequential steps.

Auto-assume done remains unavailable for todos, checklist runout routines, non-daily cadences, step routines, and Standard routines with optional checklist items.

For daily Checklist-completion routines, assumed completion is day-level routine state only. It does not store or display fake completed checklist item IDs. If the user starts checking checklist items for the current daily occurrence, that manual partial progress takes precedence and suppresses assumed-done presentation until the routine is fully completed, canceled, or progress is cleared.

## Consequences

- Daily checklist routines can be treated as default-done while still starting each day with unchecked checklist items.
- Home and Task Detail can show the routine as assumed done without showing a stale "next checklist item" prompt.
- Confirming an assumed checklist day records the same routine completion and log evidence as confirming an assumed Standard routine.
- Runout routines keep item-scoped action behavior and do not gain day-level auto-assumption.
