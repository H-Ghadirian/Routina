# 0613 — Measure loaded Planner header against visible width

Status: Accepted

The date-button behavior for a visible Focus control is refined by [0614: Collapse the Planner date label when Focus is visible](0614-collapse-planner-date-label-when-focus-is-visible.md).

Date: 2026-08-18

Refines [0612: Require comfortable width for expanded Planner header](0612-require-comfortable-width-for-expanded-planner-header.md) and [0609: Keep Planner range choices actionable in compact headers](0609-keep-planner-range-choices-actionable-in-compact-headers.md).

## Context

The Mac Planner header could look correct while Home was loading because the Planner Focus control was absent. Once data loaded, the Focus button appeared in the utility cluster, the expanded Calendar header needed more room, and the date-range button could reach the clipped edge.

The header also preferred a parent-supplied width over its own measured visible width. If that parent width was more optimistic than the actually visible header area, compact controls did not engage even though the rendered row was crowded.

## Decision

The Planner header now uses the tighter of the parent-supplied width and the header's own measured visible width when deciding between regular and compact controls.

Home also tells the Planner header whether the Planner Focus control is actually visible. A loaded Calendar header with that extra utility control requires 1720 points of comfortable expanded width, while the Calendar header without that extra control keeps the 1520-point comfort threshold. The 120-point measured reserve still applies in both cases.

## Consequences

- The loading state may remain expanded when it truly fits, but the loaded state compacts as soon as the Focus control makes the row too dense.
- An optimistic parent width can no longer prevent compact controls when the visible header is narrower.
- Timeline mode remains measured by its own control set; the extra Calendar threshold applies only to the Calendar header controls.
