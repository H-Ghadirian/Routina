# 0551: Collapse Confirmed Assumed-Done Calendar List Sections

## Status

Accepted

## Date

2026-08-11

## Refines

- [0530: Separate Confirmed Assumed Dones in Calendar List](0530-separate-confirmed-assumed-dones-in-calendar-list.md)
- [0529: Collapse Calendar List Planned Task Sections](0529-collapse-calendar-list-planned-task-sections.md)
- [0509: Collapse Calendar List Assumed-Done Sections](0509-collapse-calendar-list-assumed-done-sections.md)
- [0418: Keep Whole-History Work Out of Scrolling Render Paths](0418-keep-whole-history-work-out-of-scrolling-render-paths.md)

## Context

Confirmed assumed completions are distinct from ordinary recorded work, but a
day with many reviewed assumptions can still crowd Calendar `List` before the
person chooses to inspect it. Its separate section should have the same
compact, count-preserving interaction as the related Planned tasks and Assumed
done categories.

## Decision

On macOS, each non-empty `Confirmed assumed done` section in Calendar `List`
is a full-width disclosure, collapsed by default. It has an independent
per-day expansion choice and uses the existing Settings -> Calendar -> Calendar
List `Collapsed` / `Expanded` default only when that day column is first
shown.

The focused right-side day-task sidebar stays expanded and continues grouping
confirmed assumptions under `Dones`. Disclosure state controls only row
rendering after the cached day-task presentation is available; it does not
change counts, completion metadata, snapshot construction, or Planner
grouping while columns scroll.

## Consequences

- Dense reviewed-assumption history remains scannable while retaining
  one-click access to its rows.
- A person can inspect confirmed assumptions without expanding Planned tasks
  or Assumed done for the same day.
- The existing stored default and backup/import behavior apply without a
  preference migration.
- The Calendar List keeps its established immutable presentation-snapshot
  boundary during scrolling.
