# 0011: Open Planner Sidebar Tasks with Double Click

## Status

Accepted

## Date

2026-05-09

## Context

When the macOS planner is open, the left task sidebar doubles as a source list for selecting tasks and as a drag source for placing tasks on the plan. Single-click selection should stay lightweight so users can inspect and drag without leaving the planner, but users also need a fast pointer path back to the task detail screen from the same row.

## Decision

Task rows in the macOS left sidebar open the task detail screen on double-click while the planner is open. The single-click behavior remains task selection and list focus, and dragging from the same rows remains available for planner placement.

The double-click route uses the existing planner task-detail navigation path so it leaves planner mode, selects the task, and scrolls the regular task sidebar to the opened task when applicable.

## Consequences

- Future changes to the custom macOS task source list should preserve the distinction between single-click selection, row dragging, and planner double-click open.
- Planner blocks and planner sidebar rows share the same detail-opening behavior.
- This behavior is macOS-specific and does not imply a touch interaction on iOS.
