# 0422: Keep Mac Focus Control in Planner Timeline

## Status

Superseded by [0681: Move Mac Focus Into the New Menu](../0681-move-mac-focus-into-new-menu.md)

## Date

2026-07-24

## Refines

- [0333: Move Mac Focus Control to Planner Calendar Header](0333-move-mac-focus-control-to-planner-calendar-header.md)

## Context

The Planner header kept Focus close to planning work, but hiding it when switching from Calendar to Timeline made an important running-work control disappear solely because the user changed the Planner presentation. Timeline remains part of the Planner workspace and users may start, inspect, pause, resume, finish, or abandon focus while reviewing it.

## Decision

The Mac Planner header shows the same Focus control in both Calendar and Timeline modes, beside the Planner filter button.

The control keeps its existing task picker, tag focus, task focus, active plan-focus menu, and active non-plan focus badge behavior. Focus remains Planner-local rather than returning to the global Home toolbar.

## Consequences

- Switching between Calendar and Timeline no longer hides Focus.
- Focus behavior and session storage do not change.
- Planner retains ownership of the control without adding global toolbar crowding.
