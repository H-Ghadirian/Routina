# 0359: Show Assumed-Done Stats Summary

## Status

Accepted

## Date

2026-07-09

## Refines

- [0112: Show Estimated Actual Time Stats](0112-show-estimated-actual-time-stats.md)
- [0236: Hide Empty Stats Reports](0236-hide-empty-stats-reports.md)
- [0259: Allow Daily Checklist Auto-Assumed Completion](0259-allow-daily-checklist-auto-assumed-completion.md)
- [0268: Show Assumed-Done Routines in Planner](0268-show-assumed-done-routines-in-planner.md)

## Context

Auto-assumed daily routines can represent work that likely happened without writing completion logs until the user confirms the day. Home and Planner already expose that synthetic state, but Stats only showed recorded completion history. Users need a way to see how much daily work is currently being assumed without mixing it into factual log-based completion totals.

## Decision

Stats summary cards include assumed-done daily routine totals for the selected Stats range and active task filters:

- `Assumed done` counts eligible daily auto-assumed routine days in the range.
- `Assumed time` sums each assumed day's task estimate, treating missing estimates as zero.

These cards are reportable only when at least one assumed day exists. They do not change the recorded `Done` count, outcome charts, tag completion counts, Estimated vs Actual chart, achievements, or persisted routine history. Confirming an assumed day remains the action that creates completion log evidence.

## Consequences

- Stats can show assumed routine workload while preserving the difference between synthetic assumptions and recorded history.
- Users can compare default-done routine load against logged activity without inflating completion charts.
- Future Stats reports that need assumed completions should opt into the synthetic source explicitly instead of reading the recorded completion totals.
