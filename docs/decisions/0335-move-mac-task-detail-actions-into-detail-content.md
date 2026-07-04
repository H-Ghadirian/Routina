# 0335: Move Mac Task Detail Actions Into Detail Content

## Status

Accepted

## Date

2026-07-04

## Refines

- [0298: Close Fullscreen Mac Task Details to Planner](0298-close-fullscreen-mac-task-details-to-planner.md)
- [0302: Minimize Fullscreen Mac Task Details to the Companion Pane](0302-minimize-fullscreen-mac-task-details-to-companion-pane.md)
- [0329: Hide Mac Toolbar Actions During Search Focus](0329-hide-mac-toolbar-actions-during-search-focus.md)
- [0340: Use a SwiftUI Outlook-Style Mac Home Top Toolbar](0340-use-swiftui-outlook-style-mac-home-top-toolbar.md)

## Refined By

- [0336: Compact Mac Task Detail Companion Actions](0336-compact-mac-task-detail-companion-actions.md)

## Context

The Mac task detail action cluster included task-specific controls such as Pause, Done, link sharing, edit, minimize, and close. Keeping those controls in the app toolbar made them compete with the Home toolbar search field, especially while search expanded and while companion detail panes were open.

These controls act on the selected detail item rather than the whole Home workspace, so placing them in the global toolbar also made their ownership ambiguous.

## Decision

Mac task detail actions render as a top-trailing action cluster inside the task detail header card. The cluster keeps the existing explicit spacing and button hierarchy: `Done` remains the prominent task action, routine Pause/Resume and one-off `Cancel todo` remain secondary text actions, and link, sharing, edit, minimize, and close remain equal-size icon actions.

The app toolbar no longer owns or hides these task-specific actions during Home toolbar search expansion. It may still show principal title content and inline edit Cancel/Save actions when needed.

## Consequences

- Task detail controls remain visually owned by the selected task header, not by the global Home toolbar.
- Toolbar search expansion no longer needs to hide or restore task detail actions.
- Full Details close and minimize-back actions remain available from the detail surface itself.
- The action cluster must continue to use full-surface hit targets consistent with the app-wide button hit-area rule.
