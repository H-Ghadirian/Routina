# 0667 — Expand Mac Stats Choice Controls Instead of Their Cards

## Status

Superseded by [0669: Use Inline Menu Pickers for Mac Stats Single-Choice Filters](../0669-use-inline-menu-pickers-for-mac-stats-single-choice-filters.md)

## Date

2026-08-27

## Revises

- [0659: Progressively Reveal Mac Stats Single-Choice Filters](0659-progressively-reveal-mac-stats-single-choice-filters.md)

## Refines

- [0188: Prefer Self-Explanatory UI Over Instructional Copy](../0188-prefer-self-explanatory-ui-over-instructional-copy.md)
- [0264: Match Button Hit Areas to Visual Surfaces](../0264-match-button-hit-areas-to-visual-surfaces.md)
- [0654: Progressively Reveal Mac Planner Header Choices](../0654-progressively-reveal-mac-planner-header-choices.md)

## Context

Mac Stats adopted Planner's one-at-a-time expansion state, but expressed it as
a disclosure on each entire colored filter card. The card chevron, changing
card tint, and content revealed below the card header made the container itself
look like the edited control. Planner instead keeps surrounding layout chrome
passive and replaces a compact current-value trigger with the segmented control
that the person is editing.

The Stats sidebar should use that same control-level interaction while retaining
its vertical cards, filter meanings, and Custom Range editor.

## Decision

- Scope, Show, Time Range, Importance, and Urgency keep passive colored cards
  that identify the filter. Their card surface is not a disclosure button and
  does not change tint or stroke when the choice control opens.
- Each card shows a compact current-value trigger with a forward chevron. Opening
  it replaces that trigger with the complete segmented choice control inside
  the card, using the same leading-edge reveal language as Planner.
- One temporary expansion state still owns all five controls. Opening one closes
  another, and choosing an ordinary segmented option applies it and returns that
  control to its compact current-value trigger.
- The compact trigger owns the full clickable surface and announces the filter,
  current value, and expansion hint. Reduce Motion swaps compact and expanded
  control states without the reveal animation.
- Custom Range still keeps its date editor available while either inclusive date
  is changed. Query, Tags, and Flags remain genuine multi-value disclosure cards.
- Stats matching, persistence, caching, available options, and iOS presentation
  do not change.

## Consequences

- The interaction reads as editing a choice control rather than opening a nested
  card.
- Stats and Planner now share both the one-at-a-time state model and the visible
  compact-trigger-to-segments transformation.
- The filter card continues to provide identity and color grouping without
  becoming a competing click target.

## Supersession Note

Decision 0669 removes the temporary expansion and segmented-control state in
favor of fixed inline native menu pickers. It retains the passive cards and the
Custom Range date editor.
