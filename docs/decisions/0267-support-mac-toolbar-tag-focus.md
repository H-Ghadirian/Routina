# 0267 Support Mac Toolbar Tag Focus

Status: Accepted

Date: 2026-06-22

Refines: [0244 Start Mac Toolbar Focus With Task Picker](0244-start-mac-toolbar-focus-with-task-picker.md), [0205 Run Plan Focus From Planner](0205-run-plan-focus-from-planner.md)

## Context

The Mac toolbar focus picker already lets users choose a task before starting focus. Users also need a lighter attribution target when they are working in an area such as `#Admin` or `#Deep Work` without committing to one task first.

Plan focus remains intentionally unassigned because it starts from `Plan to do today` and can be allocated across multiple tasks later. Tag focus is different: the user chooses the tag before work starts, so it should not enter the pending unassigned allocation flow.

## Decision

The Mac toolbar focus picker supports selecting a tag below the search field. Selecting a tag filters the task list by that tag. Starting from the tag starts a tag-backed `FocusSession`; selecting a task from the filtered list still starts normal task-backed focus.

Tag focus stores the selected tag on the focus session while keeping the legacy task sentinel for compatibility. A tag focus session is not considered unassigned. It appears in running timer surfaces as `#Tag`, participates in focus stats and timeline history as tag-attributed time, and is preserved by backup/import.

Planner renders tag focus as focus calendar evidence titled with the tag. Fixed-duration tag focus creates a persisted planner block at start; count-up tag focus starts with a one-minute planner block and updates it to the actual focused duration when finished. Abandoning tag focus removes its focus-created planner block.

## Consequences

Users can record focused time against an area of work without inventing a placeholder task.

Unassigned plan/watch focus remains available for allocation workflows, while tag focus stays immediately attributed to the selected tag.

Future focus reporting should treat task focus, tag focus, unassigned focus, and board focus as distinct attribution modes even though task and tag focus share the `FocusSession` storage model.
