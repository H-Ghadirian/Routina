# 0282: Expand Day Planner Hour Spacing

## Status

Accepted

## Date

2026-06-26

## Refines

- [0191: Support One-Day Planner View](0191-support-one-day-planner-view.md)
- [0274: Present Resizable Planner Slot Draft](0274-present-resizable-planner-slot-draft.md)

## Context

Day mode lets users focus on one planner date, but the shared week-style hour spacing can still make short blocks and empty 15-minute slots feel cramped. Users who plan in smaller increments need a way to stretch the visible day so selecting, resizing, and adding blocks has more room.

## Decision

Planner Day mode supports presentation-only hour spacing controls. Users can increase or decrease the distance between hour rows through capped spacing levels. The selected spacing changes only the rendered Day mode calendar height and the interaction math that maps pointer movement to minutes.

Week mode keeps the standard hour height so the seven-day planner remains scannable. Planner blocks, timeline activity, all-day lanes, events, focus, Away, Sleep, and slot-draft persistence keep their existing storage semantics.

## Consequences

- Day mode can become roomier for micro-planning without changing stored planner data.
- Week mode remains compact enough to compare multiple days.
- Drag, drop, resize, current-time, and slot-selection layers continue to share one resolved hour height so visual placement and interaction hit testing stay aligned.
