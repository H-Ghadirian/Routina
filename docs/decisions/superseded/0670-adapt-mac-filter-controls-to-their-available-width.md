# 0670: Adapt Mac Filter Controls to Their Available Width

## Status

Superseded by [0673: Use Compact Pickers for Narrow Mac Filters](../0673-use-compact-pickers-for-narrow-mac-filters.md)

## Date

2026-08-27

## Refines

- [0188: Prefer Self-Explanatory UI Over Instructional Copy](../0188-prefer-self-explanatory-ui-over-instructional-copy.md)
- [0264: Match Button Hit Areas to Visual Surfaces](../0264-match-button-hit-areas-to-visual-surfaces.md)
- [0316: Present Mac Home Filters as a Companion Pane](../0316-present-mac-home-filters-as-companion-pane.md)
- [0660: Make Mac Planner Filters Explicit, Composable, and Bounded](../0660-make-mac-planner-filters-explicit-composable-and-bounded.md)

## Context

The Mac filter surface correctly bounded fullscreen content to 840 points, but
its controls still inherited fixed two-segment row limits from the 420-point
companion pane. Task Ladder values, Created, Media, one-time State, Grouping,
and Sort therefore used two or three rows even though every option fit on one
fullscreen row. The extra height weakened grouping, made the fullscreen view
feel like an enlarged sidebar, and left related switches at inconsistent
horizontal positions.

## Decision

- The shared filter container derives a compact or wide layout capability from
  its actual available content width, not from the fullscreen presentation flag.
- The 420-point companion pane keeps compact two-segment wrapping where needed.
  At the bounded 840-point fullscreen width, those compact row limits are
  removed so options use one equal-width row when they fit.
- Timeline Type, Status, and Media use the available card width in the wide
  layout. A feature-expanded Type catalog that is too large for comfortable
  equal-width segments retains its single-line horizontal presentation.
- Task List names its previously unlabeled status control, and switch-style
  filter rows fill their card. Appearance rows give their title-and-subtitle
  label the flexible width inside the native toggle, so their switches share a
  stable trailing column and the expanded label surface remains clickable.
- Filter meaning, selection, persistence, the 840-point maximum, and the
  minimize-back-to-pane workflow remain unchanged.

## Consequences

- Fullscreen provides a denser, more scannable desktop layout instead of
  preserving narrow-pane line breaks.
- The companion pane remains usable without truncating segment labels.
- Switches and segmented controls form consistent visual columns across Shared,
  Task List, Timeline, and Calendar.

