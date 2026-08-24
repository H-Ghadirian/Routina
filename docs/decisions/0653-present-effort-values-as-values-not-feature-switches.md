# 0653: Present Effort Values as Values, Not Feature Switches

## Status

Accepted

## Date

2026-08-24

## Refines

- [0188: Prefer Self-Explanatory UI Over Instructional Copy](0188-prefer-self-explanatory-ui-over-instructional-copy.md)
- [0642: Unify Task Configuration and Retire Legacy Task Kind Storage](0642-unify-task-configuration-and-retire-legacy-task-kind-storage.md)
- [0652: Keep Effort Fields Independent and Disclosures Honest](0652-keep-effort-fields-independent-and-disclosures-honest.md)

## Context

Add Task and Edit Task grouped Estimate, Actual time, Story points, and Focus in
an `Estimation` section. The first three optional values appeared as switches
named `Set ...`, while Focus appeared as `Show focus timer`. This made stored
values look like feature settings, made clearing a value look like disabling a
feature, and did not explain why the four controls were grouped.

The fields are related because they all describe effort, but they have distinct
meanings and persistence. Estimate is planned duration, Actual time is recorded
duration, Story points are relative size, and Focus enables attention-session
tracking.

## Decision

- The visible Add/Edit group is named `Effort` on iOS and macOS. The internal
  `estimation` case and its persisted Mac form-order raw value remain unchanged
  for compatibility.
- Time estimate, Actual time, and Story points render as independent value rows.
  A missing value has a field-specific `Set` or `Log` action; a present value
  exposes its editor and an explicit `Remove` or `Clear` action.
- Focus remains a switch because enabled/disabled is its actual data model. Its
  visible label is `Focus timer`, not `Show focus timer`.
- Each row states its meaning with compact vocabulary: planned duration,
  recorded duration, relative size, or attention-session tracking.
- Adding Actual time starts from its own 30-minute default. It does not inherit
  the task's Estimate, mutate it, or otherwise couple the two values.
- The existing task-type rule remains: task-level Actual time is offered for
  todos, while routine occurrence time stays with completion records.

## Consequences

- Related effort concepts remain discoverable in one place without looking like
  four equivalent settings.
- Adding, editing, and clearing a value have visible verbs that match the data
  mutation.
- Focus stays visibly distinct as the only true on/off capability in the group.
- iOS and macOS use the same labels, actions, defaults, and independence rules.
