# 0421 Support Cadence-Free Repeating Routines

Status: Accepted

Date: 2026-07-24

Refines: [0413 Nest Tracking Under Repeating Task Creation](0413-nest-tracking-under-repeating-task-creation.md), [0414 Align Task Kind Controls Between Create and Edit](0414-align-task-kind-controls-between-create-and-edit.md)

## Context

Some tasks are genuinely reusable but have no predictable cadence. The user knows they will do the task again, wants every completion in its history, and does not want to recreate a one-time task after every completion, but cannot honestly choose an interval or calendar schedule.

Decisions 0413 and 0414 removed `Repeat type: None` from creation to make `One-time` and `Repeating` read as a strict cadence distinction. That simplified the form but incorrectly treated reusable work with an unknown cadence as one-time work.

## Decision

Repeating routines can select `Repeat type: None` during both creation and editing.

A cadence-free repeating task:

- remains active and available immediately after each completion;
- preserves every completion in its history;
- has no interval, calendar occurrence, overdue pressure, automatic nudge, or cadence-derived daily classification;
- may be explicitly planned like another non-daily routine.

The persisted `cadenceEnabled` field controls whether a repeating routine has an active recurrence cadence.

## Consequences

`Repeating` now means reusable rather than necessarily scheduled. `Interval`, `Calendar`, and `Item runout` describe known cadence, while `None` describes reusable work whose next occurrence is determined by the user.

The cadence restriction introduced by Decisions 0413 and 0414 is reversed; their shared `One-time` / `Repeating` task-kind layout remains in effect.
