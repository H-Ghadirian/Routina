# 0328: Allow Past-Day Checklist Runout Updates

## Status

Accepted

## Date

2026-07-02

## Refines

- [0240: Keep Checklist Runout Item Actions Item-Scoped](0240-keep-checklist-runout-item-actions-item-scoped.md)

## Context

Checklist runout routines are item-scoped, but Task Details previously treated runout updates as today-only. That prevented a user from selecting yesterday and recording checklist items they had actually handled yesterday.

## Decision

Task Details lets checklist runout item actions use today or a selected past day. When the selected day is in the past, checking an item resets that item with a noon timestamp on the selected day, unchecking restores the previous runout state for that selected day, and `Extend` moves the selected item's due date one day later relative to the selected day. Future selected dates stay read-only for runout mutations.

Bulk runout completion uses the selected day when deciding which items are due and records a routine completion only when all items due for that selected day are reset.

## Consequences

- Users can backfill runout checklist work from yesterday without waiting for the item to be due today.
- Runout row checked state and status copy are derived from the selected day instead of always using the current day.
- Future-dated runout edits remain blocked so users do not accidentally move item cadence ahead of actual work.
