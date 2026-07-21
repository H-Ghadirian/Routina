# 0413 Nest Tracking Under Repeating Task Creation

Status: Accepted

Date: 2026-07-21

Refines: [0382 Split Record Task Form Controls](0382-split-record-task-form-controls.md), [0397 Make Tracking Cadence Optional](0397-make-tracking-cadence-optional.md)

## Context

The Add Task form presented `Tracking` and `Task` first, then asked whether a Task was a `Todo` or `Routine`. This exposed the storage-oriented distinction before the simpler user question: is the task one-time or repeating?

Tracking also allowed new entries with `Repeat type: None`, which made it difficult to explain as part of the recurring-work model.

## Decision

Add Task first offers `One-time` and `Repeating`. Choosing Repeating reveals a `Track this routine` toggle. Off creates a Routine; on creates Tracking with cadence enabled. Newly created Tracking cannot select `Repeat type: None`.

The internal `todo`, `routine`, and `record` task types remain unchanged. Existing Tracking entries retain edit-time support for no cadence so stored and imported compatibility data is not rewritten.

## Consequences

Creation uses the plain-language model “Todo happens once; Routine repeats,” while Tracking becomes an optional purpose of a repeating routine instead of a competing top-level concept.

Legacy no-cadence Tracking remains supported, but new no-cadence Tracking cannot be created through the full Add Task form.
