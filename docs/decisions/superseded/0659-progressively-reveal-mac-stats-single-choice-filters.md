# 0659 — Progressively Reveal Mac Stats Single-Choice Filters

## Status

Superseded by [0669: Use Inline Menu Pickers for Mac Stats Single-Choice Filters](../0669-use-inline-menu-pickers-for-mac-stats-single-choice-filters.md)

## Date

2026-08-24

## Refines

- [0188: Prefer Self-Explanatory UI Over Instructional Copy](../0188-prefer-self-explanatory-ui-over-instructional-copy.md)
- [0264: Match Button Hit Areas to Visual Surfaces](../0264-match-button-hit-areas-to-visual-surfaces.md)
- [0415: Support Custom Stats Date Ranges](../0415-support-custom-stats-date-ranges.md)
- [0599: Separate Mac Stats Priority Filters](../0599-separate-mac-stats-priority-filters.md)
- [0654: Progressively Reveal Mac Planner Header Choices](../0654-progressively-reveal-mac-planner-header-choices.md)

## Context

The Mac Stats sidebar permanently rendered the segmented choices for Scope,
Show, and Time Range, while Importance and Urgency used independent disclosure
cards. The current selections were visible, but the complete option sets and
multiple simultaneously open priority cards made the sidebar tall and visually
heavy during ordinary review.

Mac Planner established a calmer interaction for related single-choice
controls: keep each current value visible, reveal one complete segmented choice
set when requested, and collapse it after an ordinary selection. Stats needs
the same recognition-first behavior adapted to a vertical sidebar and to the
multi-step nature of Custom Range editing.

## Decision

- On macOS, Stats Scope, Show, Time Range, Importance, and Urgency render as
  compact cards that keep their current values visible while collapsed.
- One shared, temporary expansion state owns those five single-choice cards.
  Opening one collapses the previously open card, choosing an ordinary option
  applies it and collapses that card, and expansion is not persisted.
- Time Range keeps Custom Range expanded while the person edits its inclusive
  start and end dates. Once collapsed, the card summarizes the exact selected
  custom period. Choosing Today, Week, Month, or Year still collapses the card
  immediately.
- Query, Tags, and Flags keep their existing multi-value disclosures and
  searchable-picker behavior; a multi-selection workflow does not close after
  each mutation.
- Expansion and collapse animate vertically unless Reduce Motion is enabled.
  Every card header remains clickable across its full visible surface and
  exposes its current value, expansion state, and expansion hint to
  accessibility.
- Stats filter meaning, matching, persistence, cached derivation boundaries,
  available scopes, and the iOS presentation do not change.

## Consequences

- The ordinary Mac Stats sidebar is shorter and its active configuration is
  scannable without exposing every option.
- Single-choice Stats filters follow the same one-at-a-time mental model as Mac
  Planner while preserving a vertical sidebar layout.
- Custom periods remain safely editable without dismissing the two-date
  control after the first change.
- Multi-value filters retain the deliberate repeated-editing behavior they
  need.

## Supersession Note

Decision 0669 replaces progressive single-choice expansion with fixed inline
native menu pickers. Custom Range still reveals its two date fields when chosen.
