# 0184 — Sequence repeating dependencies by completion

Date: 2026-08-16

## Symptom

A repeating dependent became Blocked again immediately after its repeating
prerequisite was completed. Pausing the prerequisite to hide its newly available
next repetition also re-blocked the dependent.

## Root Cause

Relationship resolution used only the prerequisite's current presentation
status. It did not remember that the prerequisite completion had already handed
the repeating workflow to the dependent task.

## Fix

Blocked-by resolution now compares completion order. A prerequisite completion
newer than the dependent's latest completion resolves the current chain pass,
including after the prerequisite recurs or is paused. A later dependent
completion consumes that handoff and requires a new prerequisite completion.

## Prevention Rule

Model repeating workflow dependencies as ordered handoffs between completion
events, not as a snapshot of whether the prerequisite currently looks Done.
Every availability consumer must use the same history-aware resolver.

## Regression Safeguard

Shared resolver, Home, Task Details, task-row badge, and Help me choose tests
cover paused-after-completion, immediate recurrence, completion-history fallback,
and resetting the chain after the dependent completes.
