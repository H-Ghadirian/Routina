# 0577: Suggest Linked Tasks as Task Ladder Children

## Status

Accepted

## Date

2026-08-16

## Refines

- [0576: Offer Direct Repeating-Task Ladder Activation](0576-offer-direct-repeating-task-ladder-grouping.md)
- [0574: Separate Task Ladder Placement From Completion](0574-separate-task-ladder-placement-from-completion.md)
- [0418: Keep Whole-History Work Out of Scrolling Render Paths](0418-keep-whole-history-work-out-of-scrolling-render-paths.md)

## Context

A repeating commitment can now be activated as a task-backed Task Ladder group
before it has children. Existing task links often already identify meaningful
options for that commitment, but links intentionally do not imply Ladder
placement. Requiring the person to rediscover and place each linked task misses
useful evidence, while placing those tasks automatically would collapse the
placement/completion boundary established by Decision 0574.

## Decision

When the person opens a task-backed group's nested Mac Task Ladder, Routina
shows its eligible linked tasks as optional child suggestions. Link resolution
is bidirectional, so a relationship stored on either task can produce the same
suggestion. A candidate is omitted when it is already a direct child, is not
currently eligible for Task Ladder, would create a placement cycle, or the
person previously rejected that parent/task pair. Container-only groups, the
root Ladder, and tasks that are not Task Ladder groups do not show linked-task
child suggestions.

Suggestions are part of the feature-owned cached Task Ladder presentation; the
scrolling view does not resolve relationships or scan the task catalog. Each
suggestion names the existing relationship and says when acceptance will move
the task from another Ladder location.

`Accept` explicitly places the linked task inside the task-backed group. It can
move the task from another valid Ladder parent, but it does not add, remove, or
change any task relationship or completion behavior. `Reject` stores a
synchronized parent/task dismissal in Task Ladder organization and hides that
suggestion without unlinking the tasks. Manually placing the linked task inside
the parent clears the dismissal, providing a deliberate recovery path.

The dismissal field is optional in the Codable organization payload so older
saved values still decode. Dismissals are deduplicated, sorted for stable
storage, and removed when either task no longer exists.

## Consequences

- Activating Exercise as a group can immediately surface linked tasks such as
  Walk, Gym, and Swim without making placement automatic.
- The person stays in control through explicit Accept and Reject actions.
- Link direction and fulfillment semantics remain truthful after either action.
- A rejected suggestion stays dismissed across launches and synchronization,
  while manual organization can still override that choice.
- Suggestion discovery stays out of the scrolling render path and shares the
  same actionability and hierarchy rules as the rest of Task Ladder.
