# 0549: Filter Stats by Task Flags

## Status

Accepted

## Date

2026-08-11

## Refines

- [0498: Filter Task Lists by Flags](0498-filter-task-lists-by-flags.md)
- [0548: Keep iOS Stats and Timeline Filter Details in Sheets](0548-keep-ios-stats-and-timeline-filter-details-in-sheets.md)
- [0418: Keep Whole-History Work Out of Scrolling Render Paths](0418-keep-whole-history-work-out-of-scrolling-render-paths.md)

## Context

Flags identify reusable task behavior such as auto-assuming a routine done.
That can make a personal activity total less useful when a person wants to
review only deliberate work. Previously Stats could filter task activity by
tags, type, and priority, but Flags deliberately had no Stats effect. A person
with many auto-assumed completions could not see the equivalent count with an
`Assumed done` Flag excluded.

## Decision

Stats supports independent `Show stats with Flags` and `Hide stats with Flags`
rules. Each rule accepts one or more task Flags and an `All` or `Any` match
mode. A Flag cannot simultaneously be in the show and hide selection. The
controls are persisted with the other Stats filters, appear in the iOS compact
Filters sheet and the Mac Stats sidebar, and are represented in the active
filter summary.

Flag rules constrain task-bound Stats presentations: recorded done, missed,
and canceled activity; completion and creation charts; estimated and assumed
task totals; task counts; tag usage; and focus sessions associated with a
matching task. Unassigned focus remains available unless a positive Flag rule
would make its task association ambiguous. Independent sources such as Apple
Health, sleep, notes, events, and Git activity retain their own scopes.

The complete task, Flag, and activity derivation remains in the existing
reducer-owned Stats snapshot. Views read the cached result, rather than
filtering history while the dashboard scrolls.

## Consequences

- Excluding an `Assumed done` Flag immediately shows the activity total and
  related task-bound charts without those tasks.
- A person can make a focused report with `All` or `Any` Flag matching without
  repurposing organizational tags.
- Flags now affect Stats only when a person actively selects a Stats Flag
  filter; assigning a Flag continues not to alter Planner or Timeline by
  itself.
