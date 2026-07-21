# 0414 Align Task Kind Controls Between Create and Edit

Status: Accepted

Date: 2026-07-22

Refines: [0413 Nest Tracking Under Repeating Task Creation](0413-nest-tracking-under-repeating-task-creation.md)

## Context

Add Task used the plain-language `One-time` / `Repeating` choice introduced by decision 0413, while Edit Task retained the older `Tracking` / `Task` and `Todo` / `Routine` hierarchy. The same task changed conceptual models depending on whether it was being created or edited.

## Decision

Full progressive create and edit forms use the same task-kind controls: `One-time` / `Repeating`, with `Track this routine` shown for Repeating.

Editing retains one compatibility exception. An existing no-cadence Tracking entry may still select and preserve `Repeat type: None`; creation continues to require cadence for new Tracking entries.

## Consequences

Task creation and editing use one conceptual model and control layout. Existing and imported no-cadence Tracking data remains editable without making that legacy state available during creation.
