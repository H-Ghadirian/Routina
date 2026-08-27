# 0680: Align Compact Filter Titles with Equal-Width Pickers

## Status

Accepted

## Date

2026-08-27

## Revises

- [0676: Pair Compact Task Ladder Titles and Pickers](0676-pair-compact-task-ladder-titles-and-pickers.md)

## Refines

- [0188: Prefer Self-Explanatory UI Over Instructional Copy](0188-prefer-self-explanatory-ui-over-instructional-copy.md)
- [0316: Present Mac Home Filters as a Companion Pane](0316-present-mac-home-filters-as-companion-pane.md)
- [0673: Use Compact Pickers for Narrow Mac Filters](0673-use-compact-pickers-for-narrow-mac-filters.md)

## Context

Shared Task Ladder values already paired each title with its menu picker in the
compact Mac filter pane, but Task List still stacked the equivalent picker below
its title. The Task Ladder pickers also retained intrinsic widths, so their
leading edges moved with the selected value even though their trailing edges
were aligned. Both differences made adjacent compact filter forms less
consistent to scan.

## Decision

- In compact filter layout, Shared Task Ladder values and Task List Created,
  Media, one-time State, Grouping, and Sort pair a flexible leading title with a
  trailing menu picker on the same row. Task List Status uses the same row when
  its catalog is large enough to use a compact menu picker.
- These compact menu pickers share one fixed control width. Their leading and
  trailing edges therefore form stable columns as current selections change.
- Supporting Grouping explanation and conditional tag-grouping choices remain
  beneath the paired Grouping row and use the card's available width.
- Compact choices that remain segmented retain title-above-control layout.
- Wide fullscreen layout retains title-above, full-width segmented controls.
  Filter options, selection meaning, persistence, and accessibility labels do
  not change.

## Consequences

- Shared and Task List compact forms use the same leading-label/trailing-value
  rhythm.
- Menu controls do not appear to resize when their selected value changes.
- The compact pane becomes shorter without reducing fullscreen comparison space.
