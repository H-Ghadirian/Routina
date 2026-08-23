# 0643: Join iOS Task Detail Completion and Routine Actions

## Status

Accepted

## Date

2026-08-23

## Refines

- [0188: Prefer Self-Explanatory UI Over Instructional Copy](0188-prefer-self-explanatory-ui-over-instructional-copy.md)
- [0507: Clarify iOS Task Detail Action Hierarchy](0507-clarify-ios-task-detail-action-hierarchy.md)
- [0626: Join Mac Task Detail Completion and Overflow](0626-join-mac-task-detail-completion-and-overflow.md)

## Context

iOS Task Details presented completion as a wide primary button and routine
actions as a separate text-labeled button beneath it. Although the hierarchy
kept completion prominent, the detached button consumed vertical space and made
the shared lifecycle relationship less clear. An assumed completion also used
a paragraph under the task name to explain actions that the controls already
named.

The navigation overflow remains the established home for task maintenance such
as sharing, canceling, and deletion. Routine-day choices should remain near the
completion action instead of being mixed into that maintenance menu.

## Decision

On iOS Task Details:

- A routine's primary completion action and related routine-action menu form one
  joined, full-width lifecycle control. Completion remains the wide left
  segment, keeps its direct action and semantic green or orange tint, and stays
  the only prominent action.
- A narrow neutral right segment uses a downward chevron to open the native
  routine-action menu. Each segment owns its entire visual hit surface and has
  an independent accessibility label.
- When `Not today — hide until tomorrow` is available, it appears first in the
  menu and is separated from Pause, Pause Until, or Resume. The menu items keep
  text labels; only the compact trigger is icon-only.
- The top-right task-maintenance overflow stays separate.
- An assumed selected day displays a compact `Assumed done` pill beneath the
  task title instead of a visible instructional paragraph. Accessibility help
  retains the fact that the assumption is provisional until confirmed.

## Consequences

- The screen communicates state and action hierarchy through placement,
  grouping, and labels instead of repeated prose.
- Completion remains fast and visually dominant while related routine choices
  stay discoverable in context.
- Task maintenance and routine lifecycle actions preserve distinct homes.
- Compact and accessibility layouts retain separate, full-surface targets for
  completion and the menu.
