# 0317: Use Principal Search in the Mac Home Toolbar

## Status

Accepted

## Date

2026-06-29

## Refines

- [0310: Show Mac Home Toolbar Search](0310-show-mac-home-toolbar-search.md)
- [0311: Move Mac Home Mode Strip to Toolbar](0311-move-mac-home-mode-strip-to-toolbar.md)
- [0312: Move Mac Task and Timeline Filter Entry to Toolbar](0312-move-mac-task-timeline-filter-entry-to-toolbar.md)
- [0315: Merge Mac Quick Add Into Toolbar Search](0315-merge-mac-quick-add-into-toolbar-search.md)

## Refined By

- [0318: Remove Mac Home Timeline Toolbar Segment](0318-remove-mac-home-timeline-toolbar-segment.md)
- [0319: Open Planner Filters in the Home Filter Pane](0319-open-planner-filters-in-home-filter-pane.md)
- [0333: Move Mac Focus Control to Planner Calendar Header](0333-move-mac-focus-control-to-planner-calendar-header.md)

## Context

After search, Home navigation, filters, Focus, and Add all moved into the Mac Home toolbar, placing every control in one horizontal navigation cluster made the top chrome crowded. Increasing the native toolbar height alone made the row taller but did not fix the visual hierarchy.

Outlook-style Mac toolbar layouts separate global search from command controls: search occupies the centered titlebar/principal area, while command buttons stay in the toolbar row. Routina's search is the most text-heavy Home affordance and should not compete horizontally with the compact filter, Focus, mode, and Add controls.

## Decision

Mac Home renders the AppKit-backed search-or-create field as the toolbar principal item. The Home window uses expanded regular toolbar chrome so the principal search field can sit in the centered top area while compact command controls stay in the toolbar command row.

The command row keeps Home-level controls: Places when enabled, Home filters, the mutually exclusive Focus Timer branch, the primary Home mode strip, Add, and the Stats/Adventure progress picker when available. The search field keeps the same shared Home search binding, AppKit focus restoration, `Command+Option+N` focus behavior, and no-results Return-to-create guard from [0315](0315-merge-mac-quick-add-into-toolbar-search.md). [0333](0333-move-mac-focus-control-to-planner-calendar-header.md) later moves the Focus branch from this command row to the Planner Calendar header.

The search field uses Outlook-like proportions instead of the previous Quick Add overlay height. It remains large enough to be the primary global search affordance, but does not consume the command row or force the command controls into the same pill.

## Consequences

- Search has a stable, centered titlebar position that reads as the primary global search affordance.
- Filter, mode, and Add controls remain available without crowding the search field; [0333](0333-move-mac-focus-control-to-planner-calendar-header.md) moves Focus to the Planner Calendar header.
- The Quick Add shortcut and search-or-create semantics remain unchanged.
- Future toolbar changes should keep search in the principal slot and use the command row for compact action controls unless a later decision explicitly revises this layout.
