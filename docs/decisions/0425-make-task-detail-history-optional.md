# 0425: Make Task Detail History Optional

Status: Accepted

Date: 2026-07-24

Refines: [0100 Reveal Task Form Details by Section](0100-reveal-task-form-details-by-section.md), [0366 Keep Mac Task Detail Add More Inline](0366-keep-mac-task-detail-add-more-inline.md), [0393 Persist Task Detail Heatmap Per Task](0393-persist-task-detail-heatmap-per-task.md)

Refined by: [0625 Group Task Detail Add Detail With Edit](0625-group-task-detail-add-detail-with-edit.md), which moves the History entry point into the grouped header chooser.

## Context

Task Details always showed History, even when the user wanted a compact surface focused on current task information. A transient reveal action would also be lost when switching tasks or reopening the app.

## Decision

iOS and macOS Task Details hide History by default. Full Task Details offers History through Add More Details. Choosing it reveals History inline and stores that choice on the selected task.

The per-task visibility preference participates in task copying and backup/import. Existing tasks default to hidden until the user adds History.

## Consequences

- Task Details remain compact by default, regardless of whether completion or change history exists.
- Users can opt individual tasks into History without leaving Task Details.
- Once added, History stays visible for that task across navigation, relaunch, copying, and backup restoration.
