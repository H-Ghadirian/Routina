# 0648 — Keep time-varying Task Ladder values read-only in Task Details

Date: 2026-08-23

Status: Accepted

The rule summary now lists independent per-metric timing policies as defined by
[0649](0649-give-each-task-ladder-metric-an-independent-time-rule.md); the
read-only Task Detail boundary remains unchanged.

## Context

A repeating task with Changes over time has two meanings for Importance,
Urgency, and Pressure: the stored After done values that describe the task between
occurrences, and the read-only Now values derived from the next due date. Task
Details placed directly editable Base controls beside a Base/Now/target summary
and also offered a separate rule editor. A person could reasonably interpret an
edit as changing the visible Now value even though it rewrote Base, potentially
invalidating a target or changing future occurrences.

Thinking needed does not change over time, but leaving only that value editable
would split one four-value configuration across Task Details and Edit Task.

## Decision

- When a task has a configured Changes over time rule, iOS and macOS Task
  Details present all four Task Ladder values as read-only.
- Importance, Urgency, and Pressure are explicitly identified as After done values.
  The adjacent summary continues to explain Now, the due-date targets, and the
  timing. Thinking needed is identified as fixed rather than time-derived.
- Task Details does not offer a Changes over time edit action for such a task.
  Full Edit Task is the single editing path from Task Details and changes the
  four values or the rule as one coherent configuration. Task Ladder retains
  its explicitly labeled Base editing and read-only Now behavior.
- Direct Task Detail value actions are rejected at the feature boundary while
  a rule exists, so a stale picker or future presentation mistake cannot mutate
  After done values.
- Tasks without a Changes over time rule retain their existing direct Task
  Detail value controls.

## Consequences

- Base and Now can no longer be confused through an inline edit.
- A rule and the After done values that constrain its targets are changed together in
  the full editor.
- Task Details remains useful for review while avoiding a second configuration
  path.
- Thinking needed requires opening Edit Task for configured time-varying tasks,
  preserving the four-value group as one editing transaction.

## Revises

- Revises the always-directly-editable Task Detail requirement in
  [0642](0642-unify-task-configuration-and-retire-legacy-task-kind-storage.md).
- Revises the Mac progressive Task Detail picker behavior in
  [0644](0644-progressively-reveal-mac-task-detail-value-options.md) when a rule
  is configured.
- Revises the Task Detail edit action introduced by
  [0604](0604-expose-time-based-ladder-values-in-task-forms-and-details.md).
- Preserves the Base/Now derivation model from
  [0592](0592-derive-time-based-task-ladder-values-from-repeating-due-dates.md).
