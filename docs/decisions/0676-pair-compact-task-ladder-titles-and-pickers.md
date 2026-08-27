# 0676: Pair Compact Task Ladder Titles and Pickers

## Status

Accepted

## Date

2026-08-27

## Refines

- [0188: Prefer Self-Explanatory UI Over Instructional Copy](0188-prefer-self-explanatory-ui-over-instructional-copy.md)
- [0316: Present Mac Home Filters as a Companion Pane](0316-present-mac-home-filters-as-companion-pane.md)
- [0656: Make Mac All Filters Task-Ladder Complete and Searchable](0656-make-mac-all-filters-task-ladder-complete-and-searchable.md)
- [0673: Use Compact Pickers for Narrow Mac Filters](0673-use-compact-pickers-for-narrow-mac-filters.md)

## Context

The 420-point Mac filter companion pane already used menu pickers for all five
Shared Task Ladder values, but each title occupied a separate line above its
picker. That stacked treatment repeated vertical whitespace and made a compact
set of value choices read like five small sections instead of one aligned form.

## Decision

- In compact filter layout, each Shared Task Ladder metric uses one row: its
  title is leading-aligned and its intrinsic-width menu picker is trailing-aligned.
- The five rows retain their current order, labels, options, match semantics,
  bindings, accessibility labels, and persistence.
- Wide fullscreen layout retains the title-above-control treatment and the
  existing full-width single-row segmented controls.
- Other adaptive filters retain their current compact layout.

## Consequences

- The compact Task Ladder section is shorter and easier to scan as a value form.
- Picker edges form a consistent trailing column without stretching their menu
  surfaces across the row.
- Fullscreen keeps its comparison-friendly segmented presentation.
