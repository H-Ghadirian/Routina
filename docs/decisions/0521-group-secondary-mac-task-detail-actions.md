# 0521: Group Secondary Mac Task Detail Actions

Status: Accepted

Date: 2026-08-09

Refines: [0335 Move Mac Task Detail Actions Into Detail Content](0335-move-mac-task-detail-actions-into-detail-content.md) and [0487 Allow Archiving One-Off Tasks](0487-allow-archiving-one-off-tasks.md)

Refined by: [0626 Join Mac Task Detail Completion and Overflow](0626-join-mac-task-detail-completion-and-overflow.md), which joins the visible Done action and its secondary overflow into one segmented lifecycle control.

## Context

Full Mac Task Details showed Done, Archive or Pause, and Cancel todo together in
the header. That made the frequent completion action compete with secondary
lifecycle changes, and left no clear, deliberate place for the destructive
Delete action.

## Decision

Full Mac Task Details keeps Done as its only visible task lifecycle action. A
native, full-surface `…` menu groups the secondary actions for the selected
task:

- Routines show Pause or Resume.
- One-off tasks show Archive or Restore and Cancel todo when it is eligible.
- Delete is the final, separated destructive item and continues to open the
  existing confirmation dialog.

The full detail header keeps its existing link, sharing, edit, minimize, and
close controls. The compact companion pane continues to show only completion,
fullscreen, and close.

## Consequences

- The header favors everyday completion and remains easier to scan.
- Secondary and destructive changes are intentional without losing access to
  their existing lifecycle behavior.
- The existing deletion confirmation remains the final safeguard for permanent
  removal.
