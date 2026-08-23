# 0228 — Create Backlog sections at the point of use

Date: 2026-08-23

## Symptom

The Backlog workspace reserved a permanent `New super section` field even when it contained no tasks, while task move menus displayed every Backlog destination as a long flat list.

## Root Cause

Section management was treated as part of the Backlog list header instead of as an organizing action attached to the task being moved. The move-menu presentation also flattened the hierarchy that the sidebar itself already understood.

## Fix

The persistent Backlog composer was removed. Move menus now provide one nested Backlog destination with a `New Backlog Super Section…` action; creating from that action assigns the selected task. Settings remains the empty-catalog creation path, and the empty state explains both recovery routes.

## Prevention Rule

Keep creation controls at the surface where the user has the context needed to finish the operation. When a destination has hierarchy, preserve that hierarchy in menus instead of concatenating ancestor names into every row.

## Regression Safeguard

`PerformanceRegressionTests.testBacklogUsesCoalescedSemanticRefreshes` asserts that the Backlog view has no persistent composer and retains the contextual creation/menu path. The Mac Backlog hierarchy scenario documents the empty-state and nested-menu contract.
