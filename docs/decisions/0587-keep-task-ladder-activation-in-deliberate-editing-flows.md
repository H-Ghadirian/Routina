# 0587: Keep Task Ladder Activation in Deliberate Editing Flows

## Status

Accepted

## Date

2026-08-16

## Revises

- [0576: Offer Direct Repeating-Task Ladder Activation](0576-offer-direct-repeating-task-ladder-grouping.md)

## Refines

- [0188: Prefer Self-Explanatory UI Over Instructional Copy](0188-prefer-self-explanatory-ui-over-instructional-copy.md)

## Context

Decision 0576 placed `Use as Task Ladder group` in Add Task, Edit Task, and
Task Details so a repeating task could become a group before it had children.
The control is relevant to a small subset of repeating tasks, but Task Details
showed it as a prominent standalone card for every eligible task. That gave an
infrequent organizational choice more weight than the task information people
usually open Task Details to review or act on.

Add Task, Edit Task, and the Task Ladder already provide deliberate places to
make this structural choice. A person viewing an existing task can use Edit
when they intend to change its Task Ladder role.

## Decision

macOS Task Details does not show a `Use as Task Ladder group` switch or mutate
Task Ladder group activation directly.

Add Task and Edit Task retain the switch in the repeating task's Behavior card.
The Task Ladder retains its group-add and repeating-task group actions. Existing
task-backed groups, nested-task placement, synchronization, and the rule that a
group with children cannot be disabled remain unchanged.

## Consequences

- Ordinary Task Details stays focused on information and actions relevant to
  most tasks.
- Task Ladder activation remains discoverable in task creation, deliberate
  editing, and the Task Ladder workspace itself.
- Changing an existing task's group role requires entering Edit Task and saving
  the change instead of toggling organization directly from Task Details.
- Existing task groups and their children are not migrated or altered.
