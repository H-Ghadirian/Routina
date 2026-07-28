# 0447 — Resolve Selected Timed Occurrences in Task Detail

Status: Accepted

Date: 2026-07-28

Refines: [0003 Resolve Exact-Time Missed Assumptions as Done, Missed, or Canceled](0003-resolve-exact-time-missed-assumptions.md), [0348 Allow Selected Past Exact Time Backfills](0348-allow-selected-past-exact-time-backfills.md), [0358 Prefer Current-Day Missed Window Resolution From Home](0358-prefer-current-day-missed-window-resolution-from-home.md), [0434 Select Subdaily Occurrences in Task Detail](0434-select-subdaily-occurrences-in-task-detail.md)

## Context

Task Detail treated the selected current day differently from a selected past day. After today's scheduled time window ended, recurrence advancement could make the next due occurrence a later day, leaving the top completion button labeled `Missed` and disabled even though today's calendar cell represented an unresolved occurrence. Single-occurrence days also lacked the Missed and Canceled controls already available in the subdaily occurrence selector.

Users need all three factual outcomes for the exact occurrence they selected without moving to another surface or recording the outcome against the wrong day.

## Decision

For an exact-time or time-window routine, Task Detail resolves an ended occurrence on the selected current day to its scheduled occurrence timestamp even after recurrence advancement points at a later due date.

The top primary action remains the selected occurrence's Done or Undo action. For a selected day with one scheduled occurrence, the Mac calendar card separately shows eligible Missed and Canceled actions. Missed is available only after the occurrence is actually missed; Canceled is available once the occurrence has begun or passed. Future days and non-occurrence days remain non-actionable.

Days with several atomic occurrences retain the existing occurrence selector and its per-occurrence actions instead of duplicating day-level calendar controls.

## Consequences

- Today's just-ended occurrence can be completed directly from Task Detail.
- Done, Missed, and Canceled all resolve the same scheduled occurrence identity.
- Calendar selection does not silently target an older occurrence or the next recurrence.
- The top action remains visually primary while destructive or negative outcomes stay beside the selected calendar day.
