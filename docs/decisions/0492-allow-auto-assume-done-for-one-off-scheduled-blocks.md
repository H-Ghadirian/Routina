# 0492: Allow Auto-Assume Done for One-Off Scheduled Blocks

Status: Accepted

Date: 2026-08-07

Refines: [0487 Allow Archiving One-Off Tasks](0487-allow-archiving-one-off-tasks.md) and [0489 Expand Auto-Assume Done to Scheduled Repeats](0489-expand-auto-assume-done-to-scheduled-repeats.md)

## Context

One-time work can be scheduled as a specific Time block on a specific date. It has the same expected-completion shape as a repeating scheduled block, but the repeating-only auto-assume rule left that single occurrence without the same provisional completion workflow.

## Decision

Auto-assume done is available, opt-in, for a Standard one-off task only when it has exactly one availability date and a scheduled `Time block`. The assumption begins at that block's start time and applies only to that date.

One-off tasks with no date, a date window, all-day availability, an exact time, or an Available window remain ineligible. So do one-off tasks with steps or checklist items. The existing `Hide assumed-done blocks from Calendar` preference stays available after opting in and continues to default off.

The assumed completion remains synthetic until the person confirms or rejects it. It does not create completion history or a new editable Calendar placement.

## Consequences

- Add Task and Edit Task expose the existing toggle for eligible one-off Time blocks.
- Home, Task Detail, Planner day agendas, and Calendar List use the shared synthetic assumed-done occurrence for the one scheduled date.
- The narrow eligibility boundary avoids treating flexible availability as an implicit completion expectation.
