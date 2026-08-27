# 0654 — Progressively reveal Mac Planner header choices

## Status

Accepted

## Date

2026-08-24

## Revises

- [0609: Keep Planner range choices actionable in compact headers](0609-keep-planner-range-choices-actionable-in-compact-headers.md)

## Refines

- [0612: Require comfortable width for expanded Planner header](0612-require-comfortable-width-for-expanded-planner-header.md)
- [0613: Measure loaded Planner header against visible width](0613-measure-loaded-planner-header-against-visible-width.md)
- [0614: Collapse the Planner date label when Focus is visible](superseded/0614-collapse-planner-date-label-when-focus-is-visible.md)
- [0644: Progressively reveal Mac Task Detail value options](0644-progressively-reveal-mac-task-detail-value-options.md)

## Revised By

- [0681: Move Mac Focus Into the New Menu](0681-move-mac-focus-into-new-menu.md) removes the Planner-header Focus control and its date-label fit exception.

## Context

The Mac Planner used three permanently expanded segmented controls when the
header was roomy and three native current-value menus when it was tighter.
Although the menus avoided crowding, the interaction changed with window width
and hid the relationship between the current choice and its peer options.

Task Details already solves the same density problem for Task Ladder values:
each field stays compact until selected, then reveals its complete segmented
choice inline while later fields move to make room. The person requested that
Calendar/Timeline, Schedule/List, and Day/3 Days/Week use the same interaction.

## Decision

- On macOS, Planner view, Calendar task view, and Planner range each render as
  a compact current-value trigger by default. Selecting a trigger replaces only
  that trigger with its complete segmented control in place.
- One shared temporary expansion state owns all three controls. Opening one
  collapses any other expanded control, choosing any segment collapses the
  active control, and no expansion state is persisted.
- Expansion keeps the control's leading position and animates its width so
  later controls move right. Reduce Motion applies the state change without the
  transition. Every compact trigger remains clickable across its full surface
  and exposes its current value and expansion hint to accessibility.
- Planner range continues to reveal only modes the current calendar width can
  render. Preferred-range restoration, adaptive Day fallback, and readable
  day-column sizing do not change.
- `Go to date` keeps its separate icon-only fallback. The fit probe measures a
  header with the widest single choice expanded and preserves the existing
  breathing-room and comfort thresholds.
- The existing iOS segmented layout does not change.

## Consequences

- The header stays compact at every Mac width without changing from segments
  to menus as the window resizes.
- The person sees the same direct segmented choices after one click, and only
  the control being edited consumes additional width.
- Opening a control visibly pushes later choices right, matching Task Detail
  Task Ladder metrics and preserving their one-at-a-time mental model.
- Range truthfulness and the date control's anti-crowding safeguards remain
  independent from the progressive choice presentation.
