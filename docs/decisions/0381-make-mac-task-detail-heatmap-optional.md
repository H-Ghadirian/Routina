# 0381 Make Mac Task Detail Heatmap Optional

Status: Accepted

Date: 2026-07-13

Refines: [0366 Keep Mac Task Detail Add More Inline](0366-keep-mac-task-detail-add-more-inline.md), [0380 Add Record Task Type](0380-add-record-task-type.md)

Refined by: [0393 Persist Task Detail Heatmap Per Task](0393-persist-task-detail-heatmap-per-task.md)

## Context

Mac full Task Details can show a GitHub-style done heatmap for completed days. The heatmap is useful for routines and record-style logs, but it is visually dense and should not take over the default detail reading flow for every eligible task.

Records also need to remain distinct from scheduled routine behavior: they can share task metadata and actual-history presentation without exposing repeat or schedule controls.

## Decision

The done heatmap is an optional full Mac Task Detail section. It is hidden by default and can be revealed from `Add more details` with a `Heatmap` action.

The action is available for routines and records only. It is not shown in iOS, Mac companion-pane task details, or todos. Revealing the section is local to the current detail session and resets when the selected task changes.

The first heatmap iteration uses a single filled color for any day with done activity, without intensity levels.

## Consequences

Task Details stay compact by default while still letting users opt into the visual completion history where it is meaningful.

Future heatmap behavior should continue to enter through Add More unless the app adds an explicit persistent detail-layout preference.
