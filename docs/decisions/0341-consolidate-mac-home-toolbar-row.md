# 0341: Consolidate Mac Home Toolbar Row

## Status

Accepted

## Date

2026-07-05

## Refines

- [0309: Show Full Timeline in Planner List Mode](0309-show-full-timeline-in-planner-list-mode.md)
- [0311: Move Mac Home Mode Strip to Toolbar](0311-move-mac-home-mode-strip-to-toolbar.md)
- [0319: Open Planner Filters in the Home Filter Pane](0319-open-planner-filters-in-home-filter-pane.md)
- [0340: Use a SwiftUI Outlook-Style Mac Home Top Toolbar](0340-use-swiftui-outlook-style-mac-home-top-toolbar.md)

## Context

The two-row Mac Home top chrome kept search editable and prevented command controls from overlapping the Planner header, but it also left a visually empty command strip underneath the search row in common Planner Timeline layouts. The Done count and primary mode strip were useful there, but their separate row made the top of the window feel taller than the controls required.

Planner Timeline also hid the canonical `Go to date` control because the list is not range-scoped. That avoided implying the Timeline list was filtered by date, but it made it harder to jump the Planner's selected date before returning to Calendar.

## Decision

Mac Home keeps the root-owned SwiftUI top toolbar chrome, but consolidates it into one titlebar-height row. The Done status remains visible at the top of Home, the shared search-or-create field stays in the same top band, and the compact Home mode strip renders immediately to the right of the search field. Places, the optional Stats/Adventure progress picker, and the board inspector button remain toolbar controls in that same row when available. The old second command row is removed.

The search field continues to use the shared Home search binding, SwiftUI-drawn shell, transparent AppKit editor, compact and focused widths, Return-to-create guard, parser preview, and created-task toast behavior from the earlier toolbar decisions. Parser previews and created-task toasts attach below the consolidated toolbar chrome.

Planner Timeline keeps the full newest-first Timeline list and remains unscoped by Planner date or visible Calendar range. In Timeline mode, the Planner header now keeps the `Go to date` button visible beside the filter button. Pressing it opens the same right-side Planner date picker used by Calendar mode and updates the Planner selected date, primarily so returning to Calendar lands on the chosen date. Timeline mode still hides Calendar-only Today, previous/next, and Day/3 Days/Week controls.

## Consequences

- The top of Mac Home is shorter and no longer contains an empty command strip below search.
- The primary Tasks/Stats/Add mode strip stays globally reachable without taking a separate row.
- The Done count remains a top-level Home signal instead of living below the search row.
- Planner Timeline gains date-jump access without making the Timeline list date-scoped.
