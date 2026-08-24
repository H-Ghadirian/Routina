# 0237 — Do not copy Focus into actual time

Date: 2026-08-24

## Symptom

Finishing task Focus on Mac silently increased a todo's Actual time or the
latest completed routine log. iOS did not do this, and later editing or deleting
the Focus session left the copied duration unchanged.

## Root Cause

A generic completion callback crossed the boundary between Focus history and
completion evidence. The Mac task-detail host supplied that callback, then
guessed an attribution target from task kind and whichever routine completion
happened to be latest. The Focus record carried no provenance linking it to the
mutated actual-time value.

## Fix

The Focus card and task-detail wrappers no longer expose a completed-duration
callback. Finishing Focus now only closes and saves the `FocusSession`; explicit
actual-time controls remain the only task-detail path that changes stored time
spent.

## Prevention Rule

Do not copy one evidence type into another through a lifecycle callback. A
conversion into actual time must be explicit, occurrence-aware, and carry
enough attribution provenance to remain correct when either source is edited or
deleted.

## Regression Safeguard

`TaskDetailSharedViewSupportTests.taskFocusRemainsSeparateFromActualTimeAcrossPlatforms`
requires the shared Focus card and both Task Detail integrations to remain free
of a completed-duration mutation bridge. The corresponding regression scenario
is recorded in [Regression Scenarios](../scenarios/README.md#task-focus-remains-separate-from-actual-time).

See [Decision 0651](../decisions/0651-keep-task-focus-separate-from-actual-time.md).
