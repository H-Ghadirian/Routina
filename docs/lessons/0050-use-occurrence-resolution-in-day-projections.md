# 0050 — Use Occurrence Resolution in Day Projections

Date: 2026-07-27

## Symptom

An untimed monthly routine completed one day early correctly advanced to the
following month's due date, but reappeared in Home `Today` on its satisfied
scheduled day.

## Root Cause

Home planning eligibility combined the raw calendar pattern with
completion-on-today state. It did not carry the task's separate satisfied
scheduled-occurrence identity into the presentation model, so an early
completion on yesterday could not suppress today's resolved occurrence.

## Fix

The Home display model now carries `lastSatisfiedScheduledOccurrenceAt`.
Today/Tomorrow eligibility rejects a task when that occurrence identity matches
the projected day, while ordinary additive placement and actual completion
history remain unchanged.

## Prevention Rule

Any day projection that asks whether scheduled work remains must consult
scheduled-occurrence resolution identity. Actual activity dates alone cannot
represent early, late, or otherwise displaced resolution.

## Regression Safeguard

`HomeRoutineDisplayFactoryTests` verifies that the satisfied occurrence reaches
Home presentation state. `HomeTaskListFilteringTests` verifies that the early
satisfied rent occurrence is absent from `Today` but remains in `Future`.
Decision [0445](../decisions/0445-keep-satisfied-occurrences-out-of-day-planning.md)
and the early-completion scenario define the product contract.
