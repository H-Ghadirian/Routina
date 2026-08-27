# 0675: Align Task List Visibility Toggles With Appearance Rows

## Status

Accepted

## Date

2026-08-27

## Refines

- [0264: Match Button Hit Areas to Visual Surfaces](0264-match-button-hit-areas-to-visual-surfaces.md)
- [0316: Present Mac Home Filters as a Companion Pane](0316-present-mac-home-filters-as-companion-pane.md)
- [0673: Use Compact Pickers for Narrow Mac Filters](0673-use-compact-pickers-for-narrow-mac-filters.md)

## Context

Mac Task List Filters placed its three visibility toggles beneath Task type and
let their intrinsic labels center the control clusters within the card. The
adjacent Appearance tab already used a clearer full-row pattern with labels at
the leading edge, switches in one trailing column, and the whole row clickable.
Using two toggle layouts inside the same filter surface made the Filter tab less
predictable to scan.

## Decision

- `Show blocked tasks`, `Hide assumed-done tasks`, and `Show archived list`
  appear first in the Task List Filters card, before Task type.
- These controls reuse the shared Appearance toggle row: text is leading-aligned,
  switches share the trailing edge, and the full row is the native toggle target.
- Their labels, bindings, persistence, and filtering semantics do not change.
- The layout is the same in the companion pane and fullscreen presentation.

## Consequences

- Immediate visibility choices are available before categorical filters.
- Filter and Appearance toggle rows share one alignment and interaction model.
- The change is presentation-only and does not alter which tasks match.
