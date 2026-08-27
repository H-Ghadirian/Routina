# 0673: Use Compact Pickers for Narrow Mac Filters

## Status

Accepted

## Date

2026-08-27

## Supersedes

- [0670: Adapt Mac Filter Controls to Their Available Width](superseded/0670-adapt-mac-filter-controls-to-their-available-width.md)

## Refines

- [0188: Prefer Self-Explanatory UI Over Instructional Copy](0188-prefer-self-explanatory-ui-over-instructional-copy.md)
- [0264: Match Button Hit Areas to Visual Surfaces](0264-match-button-hit-areas-to-visual-surfaces.md)
- [0316: Present Mac Home Filters as a Companion Pane](0316-present-mac-home-filters-as-companion-pane.md)
- [0660: Make Mac Planner Filters Explicit, Composable, and Bounded](0660-make-mac-planner-filters-explicit-composable-and-bounded.md)

## Context

Removing compact row caps in fullscreen fixed the wide presentation, but the
420-point companion pane still gave several single-choice filters two or three
segment rows. Those rows consumed substantial vertical space and made a narrow
inspector slower to scan. A segmented control is useful when every choice fits
comfortably in one line; once the same choice must wrap, a menu picker communicates
the selected value more compactly and defers the catalog until it is needed.

## Decision

- The shared filter container continues to derive compact or wide presentation
  from its actual available width.
- In compact presentation, a single-choice filter that would otherwise require
  multiple segment rows uses a native menu picker. This applies to all five
  Shared Task Ladder metrics and Task List Created, Media, one-time State,
  Grouping, and Sort. Task List Status makes the same switch only when its
  available catalog has more than three choices.
- Compact controls whose choices already fit comfortably on one line remain
  segmented. Timeline's currently bounded Status and Media choices, the normal
  four-choice Type catalog, Task type, Goal, and All/Any controls keep their
  immediate segmented presentation.
- At the bounded 840-point fullscreen width, these adaptive controls continue
  to render as full-width, single-row segmented controls.
- Selection meaning, persistence, labels, accessibility names, fullscreen
  sizing, and minimize-back-to-pane behavior do not change.

## Consequences

- The companion pane shows substantially more filter state without scrolling.
- A person can still compare small option sets immediately while opening larger
  single-choice catalogs only when needed.
- Fullscreen retains the fast visual comparison and direct selection afforded by
  the available width.
- Future narrow Mac filter controls should use the same boundary: retain a
  segment row when it fits comfortably and use a menu picker instead of wrapping.

