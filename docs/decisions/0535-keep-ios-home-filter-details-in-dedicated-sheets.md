# 0535: Keep iOS Home Filter Details in Dedicated Sheets

## Status

Accepted

## Date

2026-08-11

## Refines

- [0534: Present iOS Priority Controls in Dedicated Sheets](0534-present-ios-priority-controls-in-dedicated-sheets.md)
- [0498: Filter Task Lists by Flags](0498-filter-task-lists-by-flags.md)
- [0314: Remove Status Grouping and Collapse Deadline Groups](0314-remove-status-grouping-and-collapse-deadline-groups.md)

## Context

After Tag and Priority moved out of the Home Filters scroll, the Group, Sort,
and Flags controls still expanded their full choices inline. The Flags section
could render every cached Flag chip and distract from the active filter state.

## Decision

iOS Home Filters represents Group rows, Task order, and Filter flags as compact
rows that show their current value and open a dedicated picker sheet.

The Group and Sort sheets keep their existing choices and bindings. The Flags
sheet keeps `All` / `Any` matching, direct clearing, and selection semantics.
It names selected Flags at the top, uses a searchable native List for remaining
cached options, and refreshes its displayed rows only when the sheet's catalog,
selection, task-list kind, or search changes.

## Consequences

- The main Filters sheet remains scannable as its controls grow.
- Active group, sort, and Flag choices stay legible without opening their
  pickers.
- Flag predicate and catalog construction remain in Home's existing cached
  refresh pipeline; scrolling picker rows do not re-filter the catalog.
