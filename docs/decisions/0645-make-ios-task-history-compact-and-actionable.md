# 0645: Make iOS Task History Compact and Actionable

## Status

Accepted

## Date

2026-08-23

## Refines

- [0188: Prefer Self-Explanatory UI Over Instructional Copy](0188-prefer-self-explanatory-ui-over-instructional-copy.md)
- [0264: Match Button Hit Areas to Visual Surfaces](0264-match-button-hit-areas-to-visual-surfaces.md)
- [0425: Make Task Detail History Optional](0425-make-task-detail-history-optional.md)
- [0507: Clarify iOS Task Detail Action Hierarchy](0507-clarify-ios-task-detail-action-hierarchy.md)

## Context

The iOS Task Detail History surface repeated each completion through a status
icon, a status badge, and a strong status-colored row glow. The timestamp had to
compete with those decorations, supplementary Persian dates wrapped inside the
same text run, and every row repeated an `Add time` pill. The only correction
action was a large status-colored swipe target, so Undo appeared completion-green
and actions were difficult to discover without swiping.

History should support quick review first and correction second. It should not
make a long record feel like a stack of primary action cards.

## Decision

iOS Task Details gives History a compact mobile presentation while macOS retains
its existing desktop presentation:

- the History container and rows use stable neutral surfaces instead of task- or
  status-colored glass glow;
- each activity row names its outcome once, supported by one semantic icon;
- the primary date/time and optional Persian date use separate lines;
- time spent appears in the row only when a duration was recorded;
- a visible 44-point actions menu provides Add/Edit Time and Undo/Remove, while
  a trailing swipe remains a shortcut for revealing the correction action;
- a full swipe only reveals the action and never performs the correction without
  a tap; and
- Undo uses orange correction semantics, while destructive record removal uses
  red.

Created metadata, Activity/Changes grouping, recent-entry limits, persisted
History visibility, and all history mutations retain their existing behavior.

## Consequences

- More history fits on screen and dates become the dominant scan target.
- Optional Persian dates remain readable without forcing mixed-calendar text
  into one crowded line.
- Time entry and correction actions are discoverable without permanently
  repeating buttons in every row.
- Accidental full-swipe history mutation is removed.
- macOS History layout and all persistence semantics remain unchanged.
