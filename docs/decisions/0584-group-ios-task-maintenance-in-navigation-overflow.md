# 0584: Group iOS Task Maintenance in Navigation Overflow

## Status

Accepted

## Date

2026-08-16

## Revises

- [0462: Use a Compact Progressive iOS Task Editor](0462-use-a-compact-progressive-ios-task-editor.md)

## Revised By

- [0594: Simplify iOS Task Detail Scan and Action Hierarchy](0594-simplify-ios-task-detail-scan-and-action-hierarchy.md) for the simple todo completion card only

## Refines

- [0061: Share Stable Routina Deep Links](0061-share-stable-routina-deep-links.md)
- [0089: Prefer Native Apple Platform Patterns](0089-prefer-native-apple-platform-patterns.md)
- [0188: Prefer Self-Explanatory UI Over Instructional Copy](0188-prefer-self-explanatory-ui-over-instructional-copy.md)
- [0507: Clarify iOS Task Detail Action Hierarchy](0507-clarify-ios-task-detail-action-hierarchy.md)

## Context

iOS Task Details placed related maintenance actions in three different places:
deep-link sharing was a dedicated navigation-bar control, canceling an eligible
todo competed with completion inside the primary action card, and deleting the
task required entering Edit Task and scrolling to the final form section.

These actions are useful but secondary to viewing, completing, or editing the
task. Their separate locations made the detail screen busier and made Delete
unnecessarily difficult to find.

## Decision

iOS Task Details uses a native top-trailing menu with a vertical-ellipsis
symbol for secondary task maintenance. The menu contains:

- the existing Share Link and Copy Link actions;
- `Cancel todo` when the selected one-off task is eligible, retaining the
  existing disabled-state rules; and
- a separated destructive `Delete Task` action that continues to require the
  existing confirmation.

Cancel todo is removed from the primary action card, leaving completion as its
only lifecycle action. Delete is removed from the iOS Edit Task form because
the detail-level overflow now owns deletion. Edit and optional Cloud sharing
remain direct navigation-bar actions. Edit mode keeps its own Cancel and Save
controls; those form-navigation actions are not part of the maintenance menu.

## Consequences

- iOS Task Details keeps its common completion and edit paths visible while
  giving secondary maintenance actions one predictable location.
- Deep-link sharing remains available without occupying its own toolbar item.
- Destructive deletion is easier to find but remains deliberate and
  confirmation-protected.
- The iOS Edit Task exception revises Decision 0462's earlier rule that its
  destructive action remains last in the form; other task forms and macOS keep
  their existing action placement.
