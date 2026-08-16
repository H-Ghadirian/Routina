# 0181 — Carry derived task state into row snapshots

Date: 2026-08-16

## Symptom

Home labeled a task `To Do` or `In Progress` while the selected Task Details
correctly showed `Blocked` because an unfinished linked prerequisite existed.

## Root Cause

Task Details derived an effective state from the relationship graph, but Home's
badge presenter continued to read only stored Todo state. macOS cached the
relationship-blocked flag without consuming it for the badge, while iOS did not
copy that derived flag into its task-row snapshots at all. The Mac Todos-only
row suppression also treated relationship-derived blocking as a neutral Todo.

## Fix

Both Home implementations now resolve active blockers once per display refresh
and carry the result in each task-row snapshot. The shared badge presenter uses
that value ahead of Ready or In Progress presentation, and the Mac Todos-only
row path keeps the resulting Blocked badge visible. Completed, canceled, and
paused presentation retains precedence.

## Prevention Rule

When a relationship-derived value is part of a task's effective presentation,
carry it into every relevant immutable display snapshot and make all renderers
consume it. Never recompute the relationship graph from scrolling rows.

## Regression Safeguard

`HomeTaskListFilteringTests` verifies Blocked badge precedence and completed-task
precedence. `HomeBlockedStatusBadgeSourceTests` verifies both platform snapshot
pipelines and the Mac Todos-only badge path; the iOS and macOS `HomeFeatureTests`
also verify that refresh builds a relationship-aware row snapshot. The Home and
Task Detail State Reflects Unresolved Prerequisites scenario records the
cross-surface contract.
