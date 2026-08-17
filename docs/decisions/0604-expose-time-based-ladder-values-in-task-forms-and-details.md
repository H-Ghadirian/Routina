# 0604: Expose Time-Based Ladder Values in Task Forms and Details

## Status

Accepted

## Date

2026-08-18

## Refines

- [0188: Prefer Self-Explanatory UI Over Instructional Copy](0188-prefer-self-explanatory-ui-over-instructional-copy.md)
- [0462: Use a Compact Progressive iOS Task Editor](0462-use-a-compact-progressive-ios-task-editor.md)
- [0534: Present iOS Priority Controls in Dedicated Sheets](0534-present-ios-priority-controls-in-dedicated-sheets.md)
- [0563: Present Importance and Urgency as Independent Task Controls](0563-present-importance-and-urgency-as-independent-task-controls.md)
- [0592: Derive Time-Based Task Ladder Values From Repeating Due Dates](0592-derive-time-based-task-ladder-values-from-repeating-due-dates.md)

## Context

Decision 0592 introduced time-based Task Ladder values for repeating Due
routines, but initial configuration lived in the Mac Task Ladder. That made the
feature easy to miss when a person was creating or inspecting the task itself.
For tasks such as rent, the stored Base values may honestly be low today, while
the person still needs to know that the task will become important, urgent, or
high-pressure on the due date or during a lead window.

The same distinction must be visible without making one-off tasks, Gentle
routines, tracking entries, or cadence-free routines appear to have due-date
heating behavior they cannot use.

## Decision

Add Task and Edit Task expose a `Time-based values` section when the draft is an
eligible repeating Due routine with active cadence, or when an existing rule is
already present and needs to remain inspectable. The editor uses the same Base,
curve, lead-window, and higher-target model as Task Ladder.

Task Details shows a compact summary for configured tasks: stored Base values,
current Now values when derivable, the selected on-due-date or gradual change,
the due-date targets, and timing context. It offers an edit action that uses the
shared rule editor. Task Ladder continues to offer the row context-menu entry and
Base/Now comparison, but it is no longer the only place where the rule can be
configured.

Unsupported schedule changes remove saved time-based targets on save rather than
leaving hidden, inapplicable behavior behind. Empty in-progress editor rules may
exist only as draft UI state; persisted task storage still keeps only valid
higher-than-Base targets for supported repeating Due routines.

## Consequences

- The person can see “low now, heats up later” while creating, editing, or
  reviewing the task, not only after opening Task Ladder.
- Progressive forms stay calm: unsupported task kinds do not show a confusing
  time-based values section unless there is an existing rule to understand or
  remove.
- Task Details becomes the explanatory surface for what the rule means on an
  individual task, while Task Ladder remains the comparison surface for Base vs
  Now across many tasks.
- The storage and derivation rules from Decision 0592 remain unchanged; this
  decision expands the configuration and explanation surfaces.
