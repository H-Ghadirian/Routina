# 0597: Show iOS Task Detail Title After Header Scrolls Away

## Status

Accepted

## Date

2026-08-16

## Revises

- [0594: Simplify iOS Task Detail Scan and Action Hierarchy](0594-simplify-ios-task-detail-scan-and-action-hierarchy.md) for navigation-principal identity only

## Refines

- [0089: Prefer Native Apple Platform Patterns](0089-prefer-native-apple-platform-patterns.md)
- [0188: Prefer Self-Explanatory UI Over Instructional Copy](0188-prefer-self-explanatory-ui-over-instructional-copy.md)

## Context

iOS Task Details permanently repeated the task emoji and a width-bounded task
name in the navigation bar while the full title remained visible in the first
card. The duplicate identity consumed scarce toolbar width, truncated otherwise
readable names, and made the top of the screen feel crowded. The navigation title
became useful only after scrolling removed the full title from view.

## Decision

On iOS Task Details:

- the navigation principal is empty while the full header title remains visible;
- once the bottom edge of that full title scrolls above the detail viewport, a
  text-only navigation title fades in;
- scrolling the full title back into view hides the navigation title again;
- the collapsed title omits the task emoji, uses the principal space available
  between navigation actions, and tightens or scales before truncating; and
- Edit Task retains its explicit edit-mode navigation title.

The transition is derived from the full title's lightweight layout anchor and
updates state only when visibility crosses the threshold. It does not perform
model work or mutate the task while scrolling. macOS presentation is unchanged.

## Consequences

- The initial screen shows one complete task title instead of two competing copies.
- The navigation bar supplies identity only when scrolling has removed the full
  title from view.
- Removing the emoji and fixed width gives long collapsed titles more usable room.
- Labels remain the accessibility source of identity even though visible title
  placement changes with scrolling.
