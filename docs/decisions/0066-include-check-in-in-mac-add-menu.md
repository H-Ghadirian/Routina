# 0066: Include Check In in the Mac Add Menu

## Status

Accepted

## Date

2026-05-26

## Context

The Mac Home sidebar `+` menu groups lightweight creation actions. It already opens Note, Goal, and Task flows, while place check-in remains available from the Home toolbar and the Places workspace. Users expect the same quick-add menu to include check-in so capture actions can start from one familiar entry point.

## Decision

The Mac Home sidebar `+` menu includes a Check In action after Note, Goal, and Task. Choosing it opens the existing Places/check-in workspace with no preselected activity, rather than creating a separate check-in implementation.

The Home toolbar check-in menu remains available for richer status, activity, suggested-place, active-place, and end-check-in actions.

## Consequences

- The sidebar `+` menu becomes a broader capture menu for notes, goals, tasks, and place check-ins.
- Check-in behavior stays centralized in the existing Places/check-in workspace.
- Future add-menu changes should preserve Check In unless a later navigation decision intentionally moves place capture elsewhere.
