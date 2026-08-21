# 0622: Preserve Planner Card Positions While Prioritizing Visibility

Date: 2026-08-21

Status: Accepted

Supersedes: [0621 Prioritize Planner Block Titles in Constrained Widths](superseded/0621-prioritize-planner-block-title-in-constrained-widths.md)

Refines: [0418 Keep Whole-History Work Out of Scrolling Render Paths](0418-keep-whole-history-work-out-of-scrolling-render-paths.md), [0454 Adapt Planner Hour Heights to Visible Density](0454-adapt-planner-hour-heights-to-visible-density.md)

## Context

The earlier Planner card adjustment correctly identified title visibility as the highest priority, but it interpreted that priority as a field-order change. The emoji or status icon must remain in its original leading position whenever it is shown; priority controls which fields are visible, not where the surviving fields are placed.

## Decision

Each macOS Planner Schedule card keeps its existing layout positions and tries these visibility candidates from most to least complete:

1. the original title, time or range, and leading emoji or status icon;
2. the same original layout without the emoji or status icon;
3. the title alone.

The card chooses the first candidate that fits its available width. This applies to each height-specific card layout, preserves the existing time formats, and does not change Planner data, timing, selection, or interaction geometry.

## Consequences

- A narrow card still begins with the emoji or status icon when that field fits.
- If space is insufficient, the icon disappears before the time or range.
- If the title and time or range still cannot fit, only the title remains.
- The priority rule no longer changes the left-to-right or top-to-bottom position of any field that remains visible.

