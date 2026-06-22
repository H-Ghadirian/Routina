# 0270: Normalize Checklist Item Intervals

## Status

Accepted

## Date

2026-06-22

## Refines

- [0176: Nest Runout Under Checklist Cadence](0176-nest-runout-under-checklist-cadence.md)
- [0186: Put Item Runout in Repeat Type](0186-put-item-runout-in-repeat-type.md)
- [0240: Keep Checklist Runout Item Actions Item-Scoped](0240-keep-checklist-runout-item-actions-item-scoped.md)
- [0263: Promote New Routine Checklists to Checklist Completion](0263-promote-new-routine-checklists-to-checklist-completion.md)

## Context

`RoutineChecklistItem` stores `intervalDays` because checklist runout routines need per-item cadence. Checklist-completion routines use the same item model, but their items are completed together as part of the routine day. Keeping authored or stale item intervals on non-runout checklist items makes ordinary checklist routines look like they carry item-level cadence even though the app does not use it.

## Decision

Checklist item intervals are canonical only for checklist runout routines. Non-runout checklist items, including checklist-completion routines and optional checklist data, normalize their stored `intervalDays` to a neutral value of `1`.

Forms, edit/save flows, task model setters, and post-open persistence migration all sanitize checklist items against the routine schedule mode. Switching away from runout clears item-level cadence by normalizing stored checklist items; switching into runout preserves or accepts clamped item intervals.

## Consequences

- Checklist-completion routines no longer preserve misleading per-item interval data.
- Legacy rows that accidentally stored non-runout item intervals are repaired when the persistent store opens.
- Runout routines keep per-item intervals because those intervals drive due calculation and item-scoped actions.
