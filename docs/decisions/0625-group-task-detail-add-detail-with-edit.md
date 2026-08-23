# 0625: Group Task Detail Add Detail With Edit

## Status

Accepted

## Date

2026-08-21

## Supersedes

- [0508 Keep iOS Add More Details Last](superseded/0508-keep-ios-add-more-details-last.md)

## Refines

- [0100 Reveal Task Form Details by Section](0100-reveal-task-form-details-by-section.md)
- [0366 Keep Mac Task Detail Add More Inline](0366-keep-mac-task-detail-add-more-inline.md)
- [0381 Make Mac Task Detail Heatmap Optional](0381-make-mac-task-detail-heatmap-optional.md)
- [0393 Persist Task Detail Heatmap Per Task](0393-persist-task-detail-heatmap-per-task.md)
- [0424 Make Task Detail Priority Optional](superseded/0424-make-task-detail-priority-optional.md)
- [0425 Make Task Detail History Optional](0425-make-task-detail-history-optional.md)
- [0521 Group Secondary Mac Task Detail Actions](0521-group-secondary-mac-task-detail-actions.md)
- [0536 Match Mac Task Detail Overflow to Toolbar Chrome](0536-match-mac-task-detail-overflow-to-toolbar-chrome.md)
- [0584 Group iOS Task Maintenance in Navigation Overflow](0584-group-ios-task-maintenance-in-navigation-overflow.md)
- [0586 Group iOS Task Detail Priority Context in the Header](0586-group-ios-task-detail-priority-context-in-the-header.md)
- [0594 Simplify iOS Task Detail Scan and Action Hierarchy](0594-simplify-ios-task-detail-scan-and-action-hierarchy.md)
- [0624 Hide Empty Linked Tasks by Default](0624-hide-empty-linked-tasks-by-default.md)

## Context

Task Details should primarily show information already attached to the selected
task. The full-width `Add more details` card remained secondary even when
collapsed, yet consumed a complete scrolling section and became visually
dominant when its option grid expanded.

Adding one missing field is a scoped editing action. Placing it in the generic
vertical-ellipsis menu would hide it among lifecycle and destructive actions,
while leaving it at the bottom separated it from the existing Edit control.

## Decision

iOS and full Mac Task Details remove the scrolling `Add more details` section.
The existing field-specific option catalog moves into a control grouped with
Edit in the task header:

- On Mac, the pencil remains a direct full Edit Task action. A narrow adjacent
  chevron opens an anchored `Add a detail` popover containing the currently
  available actions as a single list. The popover shows the available count,
  and only the chevron segment receives the active accent treatment.
- On iOS, the pencil and chevron form one native grouped control. The pencil
  remains direct Edit Task, while the chevron opens an `Add a detail` sheet with
  medium and large detents.
- When no optional action is available, the chevron is absent and Edit remains
  the ordinary single action.

Selecting an action closes the chooser before performing it. Existing
field-specific behavior remains authoritative: detail-owned controls reveal in
Task Details, Mac form-backed fields reveal their inline editor cards, and iOS
form-backed choices use their established focused edit route. The compact Mac
companion pane continues to omit editing entry points.

The vertical-ellipsis menu remains reserved for sharing, lifecycle,
cancelation, and destructive maintenance actions. Every visible segment and
chooser row owns its full hit surface and has explicit accessibility labels.

## Consequences

- Task Details end after meaningful task content instead of a wide control-only
  card.
- Full editing stays one click away, while adding one field is visibly related
  to Edit without entering the maintenance overflow.
- The chooser is lightweight and anchored on Mac, while iPhone and iPad use a
  native sheet appropriate to compact navigation.
- Existing field eligibility, persistence, inline editing, feature gates, and
  relationship behavior do not change.
