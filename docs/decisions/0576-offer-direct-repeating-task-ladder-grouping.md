# 0576: Offer Direct Repeating-Task Ladder Activation

## Status

Accepted

## Date

2026-08-15

## Refines

- [0574: Separate Task Ladder Placement From Completion](0574-separate-task-ladder-placement-from-completion.md)
- [0188: Prefer Self-Explanatory UI Over Instructional Copy](0188-prefer-self-explanatory-ui-over-instructional-copy.md)

## Revised By

- [0587: Keep Task Ladder Activation in Deliberate Editing Flows](0587-keep-task-ladder-activation-in-deliberate-editing-flows.md), which removes the direct Task Details switch while retaining Add Task, Edit Task, and Task Ladder entry points.

## Context

Task Ladder already allows a normal task to be a parent, so a real repeating
commitment such as Exercise can contain Walk, Gym, and Swim. The only path was
indirect: the person had to open each prospective child's context menu, choose
`Organize in Task Ladder…`, and recognize the repeating task in a list labelled
`Completable parents`.

Container-only groups had a visible creation action in the Task Ladder toolbar,
while the real repeating-task grouping use case had no corresponding starting
point. That made an intentional capability look unavailable.

## Decision

The Mac Task Ladder group-add control offers both `New Container Group…` and
`Use Repeating Task as Group…`.

The repeating-task flow selects an existing repeating task and one valid task
to place beneath it. The same action is available from a repeating task row,
where it becomes `Add Task to This Group…` after the task has nested work. The
flow rejects hierarchy cycles, explains when a selected child will move from
another Ladder location, and opens the resulting nested ladder after saving.

Add Task and Edit Task expose `Use as Task Ladder group` in the repeating
task's Behavior card. Repeating-task details expose the same switch directly.
These entry points allow the group to be activated before it has a first child.
An explicitly activated task group remains openable as an empty nested ladder.

The synchronized Task Ladder organization stores an optional, deduplicated set
of explicitly activated task IDs in addition to placements. Older organization
payloads without this field continue to decode. A task with placed children is
also treated as a group for compatibility, whether or not it has the explicit
marker. The marker cannot be removed while the task still owns nested tasks;
the person must move those tasks elsewhere first.

Using the flow does not convert or copy the repeating task. It keeps its
schedule, completion action, history, Home placement, Stats contribution, and
other task behavior. For each added child, the person separately chooses no
parent completion, confirmation-based `Can complete`, or automatic `Completes`
behavior, preserving the placement/completion boundary from Decision 0574.

## Consequences

- A person can begin the Exercise-style nested-ladder use case from the same
  visible group-add control used for container-only groups.
- A person can decide that a new or existing repeating task is a group while
  creating it, editing it, or viewing its details, before choosing its children.
- Repeating task semantics stay truthful; the parent remains a real task rather
  than becoming a container-only group.
- Additional tasks can be added from the repeating parent row without finding
  the reverse child-placement action.
- Explicit activation is stored alongside the existing synchronized placements
  without creating a duplicate task or container-group record; the optional
  field requires no migration for existing payloads.
