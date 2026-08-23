# 0649 — Give each Task Ladder metric an independent time rule

Date: 2026-08-24

Status: Accepted

## Context

The first Changes over time model gave Importance, Urgency, and Pressure
independent targets but forced them to share one timing curve and one lead-day
window. That made a rule such as “repeat two days after completion, gradually
over seven days before due” internally calculable but impossible to explain:
the next occurrence was born already inside a seven-day window and could start
above its stated Base value. The shared timing also prevented a task whose
Importance should jump on the due date while Urgency rises before due and
Pressure rises only if the task becomes overdue.

The editor compounded the ambiguity by separating the Base controls from the
timing controls and using different interaction models on iOS and macOS.

## Decision

- Importance, Urgency, and Pressure each own an optional policy containing a
  higher target, one timing mode, and that metric's own day count when needed.
- The timing modes have distinct calendar semantics:
  - `Only on due date` keeps the After done value before due, reaches the target
    on the due date, and keeps it while overdue.
  - `Gradually before due` advances through categorical values during that
    metric's lead window and reaches the target on the due date.
  - `Gradually while overdue` keeps the After done value through the due date,
    then advances one categorical level after each configured number of full
    overdue days until the target is reached.
- Completing an occurrence starts the next occurrence at the stored After done
  values. For an After done cadence, a before-due window is capped to the repeat
  interval, so a task that repeats every two days cannot claim a seven-day
  pre-due transition.
- Add Task, Edit Task, and the Mac Task Ladder rule sheet use the same sentence
  editor on iOS and macOS. Each sentence directly chooses the After done value,
  whether the metric changes, its timing, target, and any day count. Every
  choice uses a menu picker; the editor has no segmented control, toggle,
  checkbox, shared timing field, or stepper.
- Task Details remains read-only for configured time-varying values and lists
  each metric's independent policy beside Base/After done and Now values.
- Existing stored shared rules decode compatibly by assigning the former curve
  and lead days to every former target. They encode in the independent format
  after the next write. Recurrence-aware sanitization caps a migrated before-due
  window when necessary.

## Consequences

- The displayed sentence is the rule: it states what a value is after
  completion, when it starts changing, its target, and its rate.
- Different metrics can react to different lifecycle moments without hidden
  coupling.
- Overdue escalation is deterministic and day-based; it does not depend on a
  background mutation or silently rewrite the stored Base value.
- Short After done cycles begin at Base instead of being immediately elevated
  by a lead window longer than the cycle.
- The stored JSON shape changes without a SwiftData schema migration because
  temporal rules already use a version-tolerant serialized field.

## Revises and supersedes

- Revises the shared-curve portion of
  [0592](0592-derive-time-based-task-ladder-values-from-repeating-due-dates.md).
- Refines the form and Task Detail exposure in
  [0604](0604-expose-time-based-ladder-values-in-task-forms-and-details.md) and
  the read-only Task Detail boundary in
  [0648](0648-keep-time-varying-task-ladder-values-read-only-in-details.md).
- Supersedes [0646](superseded/0646-compact-mac-changes-over-time-editing.md).
