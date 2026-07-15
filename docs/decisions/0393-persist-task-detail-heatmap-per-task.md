# 0393: Persist Task Detail Heatmap Per Task

Date: 2026-07-15

Status: Accepted

Refines: [0381 Make Mac Task Detail Heatmap Optional](0381-make-mac-task-detail-heatmap-optional.md)

## Context

Decision 0381 made the full Mac Task Detail done heatmap optional and session-local so default task details stayed compact. In practice, adding `Heatmap` from `Add more details` and then seeing it disappear the next time that same task was opened felt like the app forgot an explicit user choice.

The desired behavior is not a global detail layout change. A heatmap added for one task should not make heatmaps appear in every routine or tracking detail.

## Decision

The full Mac Task Detail heatmap remains hidden by default and still enters through `Add more details` for eligible routine and tracking tasks only.

When the user adds `Heatmap`, Routina persists that choice on the selected task. Future full Mac Task Details for that same task show the heatmap automatically. Other tasks continue to hide the heatmap until the user explicitly adds it for those tasks.

iOS, Mac companion panes, and todos continue to omit the heatmap add action and heatmap section.

## Consequences

- Task Details stay compact by default while respecting explicit per-task customization.
- The heatmap visibility flag is task-owned data, so it is stored with the task and included in backup/restore.
- Future optional detail sections should decide whether their reveal state is session-local or task-persistent based on whether the user reasonably expects the task to remember that detail.
