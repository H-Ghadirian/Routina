# 0292: Unify Planner Header Date Control

Status: Accepted

Date: 2026-06-27

Refines: [0191 Support One-Day Planner View](0191-support-one-day-planner-view.md), [0289 Filter Planner Calendar Layers](0289-filter-planner-calendar-layers.md), [0264 Match Button Hit Areas to Visual Surfaces](0264-match-button-hit-areas-to-visual-surfaces.md), and [0188 Prefer Self-Explanatory UI Over Instructional Copy](0188-prefer-self-explanatory-ui-over-instructional-copy.md)

## Context

The Planner header showed two date surfaces: a left-side visible range title near the Day/Week picker and a right-side compact date picker near the filter button. This made the toolbar harder to scan because users had to parse which date surface was the primary navigation control.

The right side already groups Planner utility controls such as filters. Making that date surface the only date/range control keeps the toolbar calmer and makes "go to date" discoverable from the same area as other view utilities. Planner has also standardized secondary Planner content on the stable right sidebar, so date selection should use that surface instead of a floating popover.

## Decision

The Planner header uses one canonical date/range control in the right utility cluster. In Week mode the control displays the visible week range; in Day mode it displays the selected day. Pressing the control opens date selection in the right Planner sidebar, and navigating to a date updates the selected day and visible planner range.

The left header cluster is reserved for period navigation and view selection: Today, previous/next, Day/Week, and Day spacing controls when applicable. The right header cluster holds Planner utilities such as filters and the canonical date/range control.

## Consequences

- The Planner no longer duplicates the visible period in two places.
- Users can open date selection from the displayed period itself without introducing another popover.
- The toolbar has clearer separation between navigation/view controls and filter/date utilities.
