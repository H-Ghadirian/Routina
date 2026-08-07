# 0494: Allow Auto-Assume Done for Rolling After-Completion Routines

Status: Accepted

Date: 2026-08-07

Refines: [0489 Expand Auto-Assume Done to Scheduled Repeats](0489-expand-auto-assume-done-to-scheduled-repeats.md)

## Context

An `After done` routine with an interval longer than one day has no fixed calendar occurrence to derive an assumed completion from. People still want the same provisional completion workflow, but a synthetic completion must never advance a rolling interval or turn several unconfirmed offers into real history at once.

## Decision

Eligible Standard `After done` routines with a multi-day interval may opt into Auto-assume done. A real completion remains the sole rolling anchor: the first assumed offer begins after the configured interval, and every later overdue day remains assumed done until the person individually confirms one of those days.

Confirming a day advances the anchor from that confirmed completion. For example, with a two-day interval, confirmation on day 3 first offers day 5; a later completion on day 4 instead makes day 6 the next offer. Assumptions neither create history nor advance the anchor.

Rolling assumed days never expose the bulk `Confirm assumed days` action. One confirmation persists exactly one completion and clears stale synthetic offers before the next interval begins. Daily schedules retain their existing day-level bulk-confirm behavior.

Checklist-completion and item-runout routines, Standard routines with optional checklist items, step routines, cadence-free entries, and multi-occurrence-per-day schedules remain ineligible.

## Consequences

- Add Task and Edit Task show the existing Auto-assume done toggle for an eligible multi-day `After done` Standard routine.
- Home, Task Detail, Planner, and Calendar List derive the same overdue-day assumptions without creating completion logs.
- The shared Task Detail bulk-confirm handler rejects rolling intervals as a defense in depth, even if the action is dispatched outside the normal presentation.
