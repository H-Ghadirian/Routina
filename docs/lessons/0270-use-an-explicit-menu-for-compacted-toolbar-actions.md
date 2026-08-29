# 0270 — Use an explicit menu for compacted toolbar actions

Date: 2026-08-29

## Symptom

After the full iOS Task Detail title scrolled away, the collapsed task title
entered the navigation bar and the adjacent Edit/Add-detail control became an
empty circular button that did not expose either action.

## Root Cause

Task Detail left the native SwiftUI `ControlGroup` responsible for adapting when
the collapsed title reduced the available toolbar width. On iOS 26 that automatic
compaction rehosted the controls behind an unlabeled, inert pop-up trigger.
Supplying a group label alone did not make that adaptive representation reliable.

## Fix

While the full title is visible, Task Detail retains the direct Edit and
Add-a-detail `ControlGroup`. When the collapsed title appears, it deliberately
replaces that group with a pencil-labelled `Menu` containing the same semantic
`Edit task` and `Add a detail` actions. Stable accessibility identifiers expose
the collapsed title and menu to UI automation without depending on whether iOS
classifies the native menu as a button or a pop-up button.

## Prevention Rule

Do not rely on automatic toolbar `ControlGroup` compaction when a known layout
state leaves insufficient width and the compact representation is not reliable.
Render an explicit, labelled menu for that state, and keep semantic labels on
every child action.

## Regression Safeguard

The iOS Task Detail scenario requires the compacted pencil trigger to expose
both actions after the collapsed title appears.
`TaskDetailPlatformActionParityTests` protects the explicit collapsed-state menu
and its labels. `RoutinaUITests.taskDetailEditGroupRemainsActionableAfterCollapsedTitleAppears`
creates scrollable Task Detail content, scrolls until the collapsed state appears,
and opens Add a detail through the labelled menu.

Related decisions: [0597 — Show iOS Task Detail Title After Header Scrolls Away](../decisions/0597-show-ios-task-detail-title-after-header-scrolls-away.md) and [0625 — Group Task Detail Add Detail With Edit](../decisions/0625-group-task-detail-add-detail-with-edit.md).
