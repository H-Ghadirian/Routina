# 0732: Keep Mac Task Ladder Movement in Row Context Menus

## Status

Accepted

## Date

2026-09-04

## Revises

- [0722: Move Mac Task Ladder Controls to the Right Sidebar](0722-move-mac-task-ladder-controls-to-the-right-sidebar.md)

## Refines

- [0188: Prefer Self-Explanatory UI Over Instructional Copy](0188-prefer-self-explanatory-ui-over-instructional-copy.md)
- [0561: Add a Separate Mac Task-Ranking Ladder](0561-add-separate-mac-task-ranking-ladder.md)

## Context

Manually ordered Mac Task Ladder rows showed an Up and Down chevron stack on
every row. The repeated controls added a visually dominant column to a surface
whose primary purpose is comparing task names and context. The same `Move Up`
and `Move Down` actions were already available from each eligible row's context
menu.

## Decision

- Mac Task Ladder rows do not show persistent Up or Down controls.
- Each manually reorderable categorical row keeps `Move Up` and `Move Down` in
  its context menu. Rows in factual read-only views, including Estimated time,
  do not offer those actions.
- Movement keeps its existing semantics: it follows the selected display
  direction, crosses value-section boundaries when applicable, updates only the
  selected metric, and preserves that metric's independent tie-break rank.
- Inner-ladder disclosure remains visible because it communicates navigation,
  not manual ordering.

## Consequences

- Ranked rows devote their visible trailing edge to navigation only when a row
  can open an inner ladder.
- Manual ordering remains available through the native right-click or
  Control-click interaction without repeating two controls on every row.
- The Task Ladder Appearance preference does not gain a movement-control
  option; movement is a contextual action rather than row metadata.
