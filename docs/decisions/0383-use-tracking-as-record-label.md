# 0383 Use Tracking as Record Label

Status: Accepted

Date: 2026-07-13

Refines: [0380 Add Record Task Type](0380-add-record-task-type.md), [0382 Split Record Task Form Controls](0382-split-record-task-form-controls.md)

Refined by: [0384 Show Tracking as Mac Sidebar Section](0384-show-tracking-as-mac-sidebar-section.md) for Mac task-list presentation.

## Context

The internal task type is named `record` because it stores after-the-fact entries for analysis and time-spend review. In the user interface, however, `Record` reads like a generic verb or database object and does not clearly signal ongoing time analysis.

## Decision

Routina keeps the internal `RoutineTaskType.record`, `RoutineScheduleMode.record`, and persisted filter raw values such as `Records` for compatibility.

User-facing labels for this task kind use `Tracking` instead. Task forms show `Tracking` / `Task`, Home and Stats filters show `Tracking`, and timeline/task-list labels use `Tracking` while continuing to filter the same internal record-backed tasks.

Existing `record` and `records` advanced-search aliases remain valid, and `tracking` / `track` are accepted as aliases for the same internal task kind.

## Consequences

Future UI copy should use `Tracking` for this task kind unless it is describing implementation, storage, or historical decision context.

Future data/model work should continue to use the existing internal record naming unless there is an explicit migration decision.
