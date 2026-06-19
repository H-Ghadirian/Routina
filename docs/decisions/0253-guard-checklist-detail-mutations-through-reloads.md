# 0253: Guard Checklist Detail Mutations Through Reloads

## Status

Accepted

## Date

2026-06-19

## Refines

- [0249: Reset Daily Checklist Progress Each Day](0249-reset-daily-checklist-progress.md)
- [0252: Stabilize Home Task List Presentation Identity](0252-stabilize-home-task-list-presentation-identity.md)

## Context

Checklist item changes update the selected task detail optimistically while persistence, logs, and Home list reloads catch up asynchronously. Partial checklist progress already needed reload protection so stale task snapshots would not make checked rows blink unchecked.

Final checklist completion has the same risk but a different shape: completing the last item records `lastDone` and clears in-progress checklist item IDs. A stale task snapshot that still has no completion evidence can arrive before the persisted reload, briefly replacing the selected detail state and making all rows look unchecked before they return to checked. Undo has the inverse risk: the selected detail becomes unchecked, then an older completed snapshot can briefly re-check every row before the undo persistence finishes.

## Decision

Home selected-task reload guards protect every selected checklist item mutation that can be followed by an async list reload. The guard represents the selected detail task's current post-mutation state, including final completed checklist state where `lastDone` is set and in-progress checklist IDs are cleared.

Task-list reload reconciliation may accept an incoming task only when it matches the guarded mutation state. Otherwise, if the incoming task is structurally the same checklist routine, the selected detail task remains the source of truth until persistence/log synchronization catches up.

## Consequences

- Checking the final checklist item cannot flash all rows unchecked while the app waits for persistence and logs.
- Undoing checklist completion cannot flash all rows checked again while the app waits for persistence and logs.
- Partial progress, unchecked progress, final completion, and checklist-runout item changes use the same selected-detail stale-reload protection pattern.
- Future checklist mutation flows should update or reuse the selected-task reload guard instead of adding view-local anti-blink state.
