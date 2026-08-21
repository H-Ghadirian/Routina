# 0621: Prioritize Planner Block Titles in Constrained Widths

Date: 2026-08-21

Status: Superseded by [0622 Preserve Planner Card Positions While Prioritizing Visibility](../0622-preserve-planner-card-positions-while-prioritizing-visibility.md)

Refines: [0418 Keep Whole-History Work Out of Scrolling Render Paths](0418-keep-whole-history-work-out-of-scrolling-render-paths.md), [0454 Adapt Planner Hour Heights to Visible Density](0454-adapt-planner-hour-heights-to-visible-density.md)

## Context

Mac Planner Schedule cards can become narrower than the combined intrinsic width of their task title, time information, and emoji or status icon. The previous layout reserved the icon before the title, so narrow cards could show only a fragment of the title even though the title is the most useful identifier for choosing and reviewing work.

## Decision

Planner Schedule block cards use an explicit constrained-width priority order:

1. task title;
2. time or time range;
3. emoji or status icon.

The compact card layouts place the title before the time and the icon, and assign those elements descending layout priorities. Larger card layouts keep the title and time together before the trailing avatar or icon. The height-specific time formats remain unchanged, and this is presentation-only: Planner block data, timing, selection, and interaction geometry do not change.

## Consequences

- Narrow Planner columns identify the task before showing secondary decoration.
- Time or range information remains available after title space is protected.
- Emoji and status icons may yield space first when all three fields cannot fit.
- Tests should protect the explicit priority order so later card polish does not reintroduce leading-icon truncation.
