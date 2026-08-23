# 0592: Derive Time-Based Task Ladder Values From Repeating Due Dates

## Status

Accepted

## Date

2026-08-16

## Refines

- [0046: Label Routine Schedule Behavior as Due and Gentle](0046-label-routine-schedule-behavior-as-due-and-gentle.md)
- [0418: Keep Whole-History Work Out of Scrolling Render Paths](0418-keep-whole-history-work-out-of-scrolling-render-paths.md)
- [0561: Add a Separate Mac Task-Ranking Ladder](0561-add-separate-mac-task-ranking-ladder.md)
- [0575: Inherit Task Ladder Group Values From Actionable Tasks](0575-inherit-task-ladder-group-values-from-actionable-tasks.md)

## Context

A repeating responsibility can be unimportant between occurrences but urgent,
important, or high-pressure on its due date. Permanently storing that peak value
makes it compete too early and leaves it artificially elevated after completion.
Repeatedly editing the task by hand loses the distinction between its stable
baseline and its temporary, occurrence-specific need for attention.

Some responsibilities need a step change on the due date. Others need a visible
lead window in which their weight rises gradually. This derivation must remain
explainable, synchronize with the task, and avoid date calculations inside
scrolling row builders.

## Decision

A repeating Due routine with active cadence can optionally store a time-based
Task Ladder rule. Gentle routines, cadence-free routines, and one-off todos do
not use this rule.

The task's stored Importance, Urgency, and Pressure remain its baseline. The rule
can independently choose a higher due-date target for any of those dimensions
and uses one of two curves:

- `On due date` keeps the baseline before the occurrence's calendar day and uses
  the target on that day and while overdue.
- `Gradually` uses a person-selected lead-day window and advances through the
  categorical levels toward the target, reaching it on the due date.

Task Ladder offers `Base` and `Now` views for those three metrics. Base is the
editable stored ladder. Now is a read-only derived snapshot so move commands
cannot write a temporary value back into the baseline. An adjusted row labels
its due-date reason. Completing the occurrence advances the task's normal due
date, which makes the derived value return to baseline until the next lead
window. The rule is optional task-owned storage and participates in normal
SwiftData synchronization, sharing, detached copies, backup, and import.

The cached Task Ladder presentation resolves effective values once when source
data, view mode, or the calendar day changes. Scrolling rows consume only cached
sections and metadata. A container group that inherits a metric uses child base
values in Base and child effective values in Now.

## Consequences

- Stable task meaning and temporary occurrence pressure are both visible without
  silently rewriting one another.
- A due-date completion resets attention through the existing recurrence model;
  no separate cleanup mutation or delayed job is required.
- Gradual movement is deliberately categorical and day-based, matching Task
  Ladder's value sections rather than inventing a hidden continuous rank.
- Now mode cannot be manually reordered because its section membership may change
  at the next day or completion boundary.
- The initial implementation configured and viewed time-based rules in the
  development Mac Task Ladder. [0604](0604-expose-time-based-ladder-values-in-task-forms-and-details.md)
  extends the same rule into task creation, editing, and detail explanation
  surfaces without changing the derivation model.
