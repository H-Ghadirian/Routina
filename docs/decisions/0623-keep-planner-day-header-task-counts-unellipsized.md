# 0623: Keep Planner Day Header Task Counts Unellipsized

Date: 2026-08-21

Status: Accepted

Refines: [0288 Open Planned Day Task List From Planner Headers](0288-open-planned-day-task-list-from-planner-headers.md), [0609 Keep Planner Range Choices Actionable in Compact Headers](0609-keep-planner-range-choices-actionable-in-compact-headers.md)

## Context

The compact planned-task button in a Planner day header can have enough visible room for its count, while SwiftUI still proposes a compressed width to the inner `Label`. A one-line label then renders an ellipsis even though the button's minimum width is present.

## Decision

The day-header task-count label reserves its intrinsic horizontal width before padding and the button's minimum frame are applied. The visible count remains the numeric value capped at `99+`; accessibility and help text continue to expose the uncapped count and category breakdown.

## Consequences

- Day-header task counts remain readable whenever the button can fit in the column.
- The button's existing visual minimum and full click target remain unchanged.
- This is presentation-only and does not change task filtering, counts, sidebar contents, or Planner data.

