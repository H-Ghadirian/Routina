# 0614 — Collapse the Planner date label when Focus is visible

Status: Superseded by [0681: Move Mac Focus Into the New Menu](../0681-move-mac-focus-into-new-menu.md)

Date: 2026-08-18

Refines [0613: Measure loaded Planner header against visible width](../0613-measure-loaded-planner-header-against-visible-width.md), [0612: Require comfortable width for expanded Planner header](../0612-require-comfortable-width-for-expanded-planner-header.md), and [0609: Keep Planner range choices actionable in compact headers](../0609-keep-planner-range-choices-actionable-in-compact-headers.md).

## Context

The Mac Planner header fit while Home was loading, but the textual `Go to date` control could still reach beyond the trailing edge when loaded data added the Focus control. Making all header controls depend on one measured compact state did not reliably remove the date label during that loaded transition.

## Decision

In Mac Calendar, a visible Planner Focus control independently makes `Go to date` icon-only. The Planner view, task-view, and range controls keep their own compact-fit decision and may remain expanded when the room recovered from the date label is sufficient.

The icon keeps the same action, full click target, accessible label, selected date or range value, hint, and help.

## Consequences

- Loading data cannot add Focus while retaining the long date label in the same Calendar header.
- Only the control responsible for the unnecessary trailing width is collapsed first.
- Timeline keeps its regular date label unless its own header enters compact mode.
