## Planner block cards prioritize visibility without reordering

Area: Planner

Decision links: [0622](../decisions/0622-preserve-planner-card-positions-while-prioritizing-visibility.md), [0454](../decisions/0454-adapt-planner-hour-heights-to-visible-density.md)

Current behavior: [Planner](../current-behavior/planner.md)

Coverage:
- `Tests/Shared/DayPlanPlannerStateTests.swift`

Given Mac Planner Calendar `Schedule` shows a timed block in a narrow day column
When the card cannot comfortably fit its title, time or range, and emoji or status icon
Then the original title, time or range, and leading emoji or status icon positions are used whenever all fields fit
And the leading emoji or status icon is omitted before the time or range
And the time or range is omitted before the title
And the title remains visible as the final fallback
And fields that remain visible do not change their original positions
And the block's stored timing, selection, and interaction behavior remain unchanged
