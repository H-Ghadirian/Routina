# 0353: Move Mac Task Form Actions Into Identity

## Status

Accepted

## Date

2026-07-08

## Refines

- [0335: Move Mac Task Detail Actions Into Detail Content](0335-move-mac-task-detail-actions-into-detail-content.md)

## Context

Mac task creation and inline task editing both use the same progressive task form. Keeping their Cancel and Save controls in the app toolbar made those form-owned actions compete with Home toolbar search and mode controls, and separated the save decision from the identity fields users most often review before committing.

Decision 0335 moved task-detail actions into content but allowed inline edit Cancel/Save to remain in the toolbar. The Add Task form now follows the same content-owned action pattern, so inline edit should match it.

## Decision

Mac Add Task and Mac inline task editing render Cancel and Save in the task form Identity section. The app toolbar does not emit cancellation or confirmation toolbar items for those task form surfaces.

Inline edit may keep a principal `Edit Task` title in the toolbar because it identifies the current mode rather than acting on the form. Save remains disabled until the edit form has a valid change to commit.

## Consequences

- Form actions stay visually owned by the task form instead of the global Home toolbar.
- Add and edit task forms share the same action placement.
- The Home toolbar stays quieter while task form surfaces are open.
