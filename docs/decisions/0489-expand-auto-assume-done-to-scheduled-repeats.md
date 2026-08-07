# 0489: Expand Auto-Assume Done to Scheduled Repeats

Status: Accepted

Date: 2026-08-06

Refines: [0259 Allow Daily Checklist Auto-Assumed Completion](0259-allow-daily-checklist-auto-assumed-completion.md), [0387 Keep Completed Scheduled Blocks Visible](0387-keep-completed-scheduled-blocks-visible.md), [0398 Move Auto-Assume Done to Tracking](0398-move-auto-assume-done-to-tracking.md)

## Context

Auto-assume done had been limited to daily Tracking. That made a scheduled repeating task such as a weekday time block impossible to treat as expected-complete, even when the user explicitly wanted the same review workflow.

The old Calendar rule also hid every task-backed block for an assumed occurrence. That is wrong for a repeating time block: it remains useful calendar context even while its completion is provisional.

## Decision

Auto-assume done is available, opt-in, to eligible repeating Tasks and Tracking entries. A recurrence must either be daily or be a scheduled, single-occurrence-per-day calendar pattern; an assumption is derived only on days where that pattern has an occurrence. The existing exclusions remain: todos, cadence-free entries, non-daily after-completion repeats, item runout, routines with sequential steps, Standard routines with optional checklist items, and schedules with multiple occurrences in one day cannot enable it. Checklist-completion entries remain eligible only when they contain checklist items.

An assumed occurrence remains synthetic until confirmed. It does not create a completion log or a new editable Calendar placement.

Task-backed time and all-day blocks stay visible in Calendar by default when their occurrence is assumed done. Forms show `Hide assumed-done blocks from Calendar` only after Auto-assume done is enabled. This per-task preference defaults off and restores the prior suppression behavior when enabled.

## Consequences

- Users can record a scheduled weekly, monthly, yearly, or one-per-day repeating task as normally expected while retaining the ability to confirm or reject the assumption.
- A Calendar block continues to communicate its planned time by default, while Calendar List and day agendas continue to present the synthetic assumed-done review state.
- Existing persisted auto-assume values retain their storage field for compatibility; the new Calendar-visibility preference is backed up and shared with the task.
