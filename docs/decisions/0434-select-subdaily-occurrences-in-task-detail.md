# 0434 — Select Subdaily Occurrences in Task Detail

Status: Accepted

Date: 2026-07-26

Refines: [0433 Identify Subdaily History by Scheduled Occurrence](0433-identify-subdaily-history-by-scheduled-occurrence.md)

## Context

Task Detail's calendar intentionally navigates by day, but a subdaily routine can have several independent occurrences on that day. A single primary action targeting the next due occurrence did not let users inspect sibling states or deliberately resolve a particular scheduled time. History exposed the timestamps only after a resolution already existed.

## Decision

When the selected day contains more than one occurrence for a standard single-day routine, Task Detail shows one shared occurrence selector on iOS and macOS.

Each occurrence displays its scheduled time and an independently derived state: Done, Missed, Canceled, Ready, or Upcoming. Selection is transient Task Detail state and resets when the calendar day changes. The selected timestamp becomes the target for Task Detail status, completion, and undo behavior.

The selected occurrence offers only actions valid for its current lifecycle:

- Done records that exact scheduled occurrence and can replace a recorded Missed or Canceled resolution.
- Confirm missed and Cancel are available only where exact-time lifecycle tracking supports them.
- Clear status removes only that occurrence's recorded resolution, after the existing confirmation flow.

Sequential-step, checklist-driven, and multi-day routines do not show the selector because their progress spans more than one atomic occurrence completion.

## Consequences

- Same-day routine times are visible and actionable without opening history.
- Visual state and mutation identity use the same scheduled timestamp.
- The calendar remains a compact day-navigation surface.
- No persistence migration is needed; selection uses the timestamp identity established by Decision 0433.
- Hourly routines can show their generated occurrences, but unsupported Missed/Cancel actions remain absent instead of inventing a second lifecycle contract.
