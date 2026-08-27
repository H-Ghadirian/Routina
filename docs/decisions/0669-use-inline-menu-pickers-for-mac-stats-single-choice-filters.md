# 0669 — Use Inline Menu Pickers for Mac Stats Single-Choice Filters

## Status

Accepted

## Date

2026-08-27

## Supersedes

- [0659: Progressively Reveal Mac Stats Single-Choice Filters](superseded/0659-progressively-reveal-mac-stats-single-choice-filters.md)
- [0667: Expand Mac Stats Choice Controls Instead of Their Cards](superseded/0667-expand-mac-stats-choice-controls-instead-of-their-cards.md)

## Refines

- [0188: Prefer Self-Explanatory UI Over Instructional Copy](0188-prefer-self-explanatory-ui-over-instructional-copy.md)
- [0264: Match Button Hit Areas to Visual Surfaces](0264-match-button-hit-areas-to-visual-surfaces.md)
- [0415: Support Custom Stats Date Ranges](0415-support-custom-stats-date-ranges.md)
- [0599: Separate Mac Stats Priority Filters](0599-separate-mac-stats-priority-filters.md)

## Context

Mac Stats progressively revealed segmented choices for Scope, Show, Time Range,
Importance, and Urgency. Although that kept the ordinary sidebar compact, every
selection still required a temporary expansion, changed the card height, and
moved later filters. These controls are single-choice filters whose complete
option lists do not need to remain visible after a choice.

A native Mac menu picker can keep the current value visible in the same compact
row, provide the complete list on demand, and avoid disclosure state or sidebar
reflow. Custom Range is different only because it needs two values after the
person chooses it.

## Decision

- Scope, Show, Time Range, Importance, and Urgency each use a native menu-style
  picker inline with the filter title inside the existing passive colored card.
- The picker always shows the current choice. The five filters have no shared or
  per-card expansion state, segmented option surface, or expansion animation.
- Time Range includes Today, Week, Month, Year, and Custom in the same menu.
  Selecting Custom reveals only the inclusive From and Through date fields
  beneath its row. Selecting a preset removes those fields again.
- Importance and Urgency remain independent minimum-threshold pickers. Choosing
  All clears only that axis and preserves the other one.
- Picker labels remain available to accessibility even though the adjacent card
  title supplies the visible label.
- Query, Tags, and Flags retain their disclosure or searchable multi-value
  workflows. Stats matching, persistence, caching, available options, and the
  iOS presentation do not change.

## Consequences

- Ordinary single-choice filtering no longer changes card height or moves later
  controls in the sidebar.
- All five filters use one consistent native Mac interaction and expose the
  current configuration at a glance.
- The sidebar expands only for configuration that genuinely needs additional
  fields: a custom date range or a complex multi-value filter.
