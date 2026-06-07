# 0175: Use Routine Finish Mode for Checklist Creation

## Status

Accepted

## Date

2026-06-07

Refines [0045](0045-split-routine-schedule-behavior-and-format.md), [0069](0069-support-optional-task-checklists.md), and [0101](0101-treat-empty-checklists-as-optional-task-details.md) for routine creation and editing.

## Context

Routine forms had two visible paths that both appeared to add a checklist: the `How it finishes` routine format picker, and the optional Checklist button in More Details. The two paths represented different concepts, but sharing the same label made routine creation confusing and introduced ambiguous states.

## Decision

Empty standard routines no longer offer Checklist as an optional More Details reveal. To create a routine with checklist items, users choose the Checklist or Runout finish mode, which reveals the checklist item editor as required setup for that routine format.

Todos still support checklist as an optional detail. Existing or in-progress checklist items on standard routines remain visible and editable so older data and draft content are not hidden or lost.

## Consequences

- Routine creation has one clear checklist entry path.
- Existing optional checklist data on standard routines remains preserved.
- Code still must not assume `RoutineTask.checklistItems` means a checklist-driven schedule mode.
- Future checklist-related routine UI should distinguish routine finish behavior from optional todo details.
