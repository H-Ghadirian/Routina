# 0700: Hide Inert iOS Stats Toolbar Controls

## Status

Accepted

## Date

2026-08-30

## Refines

- [0113](0113-allow-stats-dashboard-reordering.md)
- [0188](0188-prefer-self-explanatory-ui-over-instructional-copy.md)
- [0236](0236-hide-empty-stats-reports.md)
- [0505](0505-use-dense-ios-stats-metric-tiles.md)

## Context

iOS Stats kept its Cards/Compact, Edit, and Filter toolbar controls visible even
when the current data left those actions with nothing to affect. Edit could open
an empty mode whose Add and Reset actions were disabled, and the other buttons
could open choices that could not change the empty dashboard. Disabled or inert
chrome made the empty state look unfinished and implied unavailable work.

At the same time, hiding controls solely because the visible dashboard is empty
would remove valid recovery paths. A hidden report still needs Edit so it can be
restored, and an active sheet filter still needs Filter so it can be cleared.

## Decision

iOS Stats derives each toolbar control from the capability it can currently
affect:

- Cards/Compact appears only when the selected scope has at least one visible,
  reportable summary item.
- Edit appears whenever at least one reportable dashboard item is available,
  including when the person has hidden every such item. If reportability
  disappears during editing, Stats exits edit mode and dismisses Add.
- Filter appears when task data is available to filter or when a sheet filter is
  already active and needs a recovery path. Selecting a non-default date range
  does not keep Filter visible by itself because the range control remains
  directly available above the dashboard.

The three controls are all absent from a genuinely empty, unfiltered Stats
dashboard. macOS availability remains unchanged.

## Consequences

- Empty iOS Stats surfaces no longer advertise actions that cannot change the
  result.
- Hidden reports and active filters remain recoverable.
- Toolbar controls can appear independently when only one capability is useful;
  they are not treated as one all-or-nothing group.
