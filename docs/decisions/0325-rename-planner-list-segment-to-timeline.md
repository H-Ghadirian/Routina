# 0325: Rename Planner List Segment to Timeline

## Status

Accepted

## Date

2026-07-01

## Refines

- [0309: Show Full Timeline in Planner List Mode](0309-show-full-timeline-in-planner-list-mode.md)
- [0318: Remove Mac Home Timeline Toolbar Segment](0318-remove-mac-home-timeline-toolbar-segment.md)
- [0320: Hide Planner Range Picker in Tight Inspector Layouts](0320-hide-planner-range-picker-in-tight-inspector-layouts.md)

## Context

Planner list mode became the main Mac route for reviewing the full Timeline after the Home toolbar stopped showing Timeline as a separate mode-strip segment. Keeping the segment label as `List` made that route less clear because the content is the user's Timeline, not a generic list view.

The existing internal list-mode behavior is still correct: it uses all Timeline-style entries, newest-first ordering, Home Timeline filters, and Calendar-only range controls stay hidden.

## Decision

The Mac Planner display-mode segmented control labels the modes `Calendar` and `Timeline`.

Selecting `Timeline` keeps using the existing Planner list-mode state and behavior. The underlying `DayPlanDisplayMode.list` case, persistence boundaries, filtering semantics, routing, and range-independent full-Timeline content remain unchanged.

When the header is too narrow, the Calendar/Timeline label text can still collapse to icon-only before the date/range button switches to compact width.

## Consequences

- The toolbar-accessible full Timeline route is named by what the user sees.
- Existing Planner list-mode behavior and data boundaries do not change.
- Prior decisions that describe the implementation as List mode remain historical context, refined by this user-facing label.
