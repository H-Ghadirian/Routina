# 0695: Promote Stats and Settings in iOS Navigation

## Status

Accepted

## Date

2026-08-29

## Supersedes

- [0033: Use an App-Owned iOS More Tab](superseded/0033-use-app-owned-ios-more-tab.md)
- [0097: Preserve Compact More Destination Across Tab Switches](superseded/0097-preserve-compact-more-destination.md)
- [0173: Use iOS New Tab Sheet](superseded/0173-use-ios-new-tab-sheet.md)
- [0458: Align iOS New Actions With Beta Gates](superseded/0458-align-ios-new-actions-with-beta-gates.md)
- [0459: Route a Single iOS New Action Directly](superseded/0459-route-single-ios-new-action-directly.md)
- [0540: Group iOS Task Reviews Under One More Destination](superseded/0540-group-ios-task-reviews-under-more-destination.md)
- [0601: Keep iOS Task Reviews Development-Only](superseded/0601-keep-ios-task-reviews-development-only.md)

## Revises

- [0071: Move iOS Task Add to the Tab Bar](0071-move-ios-task-add-to-tab-bar.md)
- [0212: Hide Goals Tab by Default](0212-hide-goals-tab-by-default.md)
- [0543: Defer iOS Sync Refresh Work Until Its Tab Is Active](0543-defer-ios-sync-refresh-work-until-its-tab-is-active.md)
- [0664: Open iOS Workspaces From the Home List](0664-open-ios-workspaces-from-the-home-list.md)

## Context

The compact iOS tab bar used Home, Search, New, Timeline, and an app-owned More
destination. Stats and Settings were therefore one level below the tab bar even
though they are primary review and configuration surfaces. Timeline had both a
dedicated tab and a native Home workspace row, while More existed chiefly to
avoid automatic UIKit overflow and then accumulated development review routes.

New also grew into a feature-gated capture catalog. That made its contents
change with experiments and obscured the two global actions that should remain
predictable: creating a task and starting Focus.

## Decision

iOS uses Home, Search, New, Stats, and Settings as its standard primary tab
destinations, in that order. Stats and Settings are direct destinations on both
compact and regular iOS layouts. Timeline and the app-owned More destination no
longer occupy tab-bar items.

Timeline remains a native row at the end of Home between Backlog and Task
Ladder, reusing Home's navigation hierarchy and the existing cached Timeline
feature. Existing note, event, and sleep deep links can still present Timeline
directly as a non-tab fallback; dismissing that fallback returns to Home.

Tapping New always presents exactly two rows in stable order:

1. Create Task opens the existing Smart Add task flow.
2. Focus opens the attributed Focus picker with count-up and fixed-duration
   choices, searchable active tasks, and available task tags. If a task, tag,
   unassigned, or sprint Focus timer is already active, the action opens that
   timer's controls instead of offering a conflicting start.

Optional Event, Emotion, Note, Goal, Check In, Away, and Sleep actions no longer
appear in New. Their persisted feature settings and their other supported
surfaces remain compatible. The former `Show Going to sleep in New sheet`
setting is no longer presented. Development task-review procedures no longer
occupy an iOS primary-navigation route in this change.

The shared `Tab.timeline` and `Tab.more` values remain decodable for deep-link,
temporary-view-state, and cross-platform compatibility. On iOS, a restored More
selection resolves to Settings, while a restored Timeline selection uses the
non-tab Timeline fallback.

## Consequences

- Stats and Settings each take one tap from anywhere in the iOS app.
- The compact iOS tab bar has five stable items without an automatic or
  app-owned More hierarchy.
- New has a stable two-choice meaning that is independent of Beta Experiment
  availability.
- Timeline remains discoverable from Home without duplicating a tab slot, and
  existing Timeline deep links continue to resolve.
- Focus startup performs its task/session fetch only after the person selects
  Focus; the app shell does not query or derive the picker from a scrolling
  render path.
- Existing feature-specific capture routes can continue to evolve without
  changing the global New chooser.
