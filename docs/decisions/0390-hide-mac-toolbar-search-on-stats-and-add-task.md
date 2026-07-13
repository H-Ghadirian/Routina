# 0390 Hide Mac Toolbar Search on Stats and Add Task

Status: Accepted

Date: 2026-07-13

Refines: [0317 Use Principal Search in the Mac Home Toolbar](0317-use-principal-search-in-mac-home-toolbar.md), [0341 Consolidate Mac Home Toolbar Row](0341-consolidate-mac-home-toolbar-row.md), [0353 Move Mac Task Form Actions Into Identity](0353-move-mac-task-form-actions-into-identity.md)

## Context

The consolidated Mac Home toolbar made search a stable top-level affordance for task, Timeline, Planner, board, and goal surfaces. That same always-visible search pill adds noise on surfaces where it does not help the current job.

Stats is primarily a reading and filtering dashboard with its own sidebar controls, and Add Task is a form-owned creation surface. On Add Task, decision 0353 already moved form actions into the Identity section so the app toolbar would stay quieter while the user is writing the task.

## Decision

Mac Home keeps the root-owned top toolbar row, sidebar toggle, mode strip, and surface-specific controls, but hides the central toolbar search pill while the selected surface is Stats, Adventure, or Add Task.

When entering one of those non-search toolbar surfaces, any active toolbar search focus is dismissed and the visible pill width returns to compact state. The configurable Quick Add/search-focus command does not focus or expand a hidden toolbar search field on those surfaces.

The toolbar search remains available on task-list, Timeline/Planner, board, goals, and other searchable Home surfaces with the existing shared search binding, quick-create guard, Command-Return seeded Add Task route, parser preview, and created-task toast behavior.

## Consequences

Stats and Add Task have quieter top chrome that better matches their surface-owned controls.

Search-driven task creation remains anchored to searchable task and Timeline contexts instead of appearing over the full Add Task form.

Future toolbar changes should keep search visibility tied to whether the active surface benefits from task or Timeline search, rather than treating the search pill as mandatory on every Home mode.
