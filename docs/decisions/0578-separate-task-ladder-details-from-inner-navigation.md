# 0578: Separate Task Ladder Details From Inner Navigation

## Status

Accepted

## Date

2026-08-16

## Refines

- [0577: Suggest Linked Tasks as Task Ladder Children](0577-suggest-linked-tasks-as-task-ladder-children.md)
- [0576: Offer Direct Repeating-Task Ladder Activation](0576-offer-direct-repeating-task-ladder-grouping.md)
- [0574: Separate Task Ladder Placement From Completion](0574-separate-task-ladder-placement-from-completion.md)
- [0188: Prefer Self-Explanatory UI Over Instructional Copy](0188-prefer-self-explanatory-ui-over-instructional-copy.md)

## Context

Task Ladder group rows previously used one click to enter their nested ladder.
That made a task-backed group behave differently from an ordinary task row:
the person could not select Exercise and see its task details without finding
the row's context-menu action. A container-only group had the same problem for
its group summary and edit action.

The row has two distinct destinations: details about the selected group, and
the ranked list inside it. These should not compete for the primary click.

## Decision

One click or primary activation on any Mac Task Ladder row selects it and shows
its details. For a task-backed group, these are the normal task details. For a
container-only group, these are the group summary, actionable child count, and
Edit Group action.

Double-clicking a container group, an explicitly activated task group, or a
task with nested children opens its inner Task Ladder. The first click may
select the group before the second click navigates, matching ordinary desktop
selection/open behavior without delaying detail selection. Rows that cannot
open an inner ladder continue treating activation only as detail selection.

The row help and accessibility hint explain the double-click destination.
Context menus retain explicit `Show Group Details` and `Open Inner Task Ladder`
commands so inner navigation does not depend exclusively on a pointer gesture.
Programmatic flows that deliberately create or add to a group may still open
the resulting inner ladder directly.

Container-group selection is feature state, independent of nested scope. It is
cleared when a task is selected or the group is deleted, and the selected
group's child count is derived from the same cached eligible-task snapshot as
the Ladder presentation.

## Consequences

- A single click has one consistent meaning across Task Ladder rows: show the
  selected item's details.
- Exercise can be inspected as a real repeating task without accidentally
  leaving the root Ladder.
- A container group can be inspected and edited before entering its contents.
- Opening nested peers remains a deliberate double-click or explicit context
  menu action.
- Keyboard and assistive activation still reaches details, while the explicit
  menu command preserves an accessible route to the inner ladder.
