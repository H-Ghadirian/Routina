# 0230 — Retire pre-release concepts through the whole stack

Date: 2026-08-23

## Symptom

A removed task kind no longer appeared in the main form, but compatibility enum cases, schedule modes, schema fields, help aliases, conditional UI branches, source-based tests, and documentation still described or protected it. That stale layer could mislead future implementation work and made ordinary Routine behavior difficult to reason about.

## Root Cause

The first cleanup stopped at presentation boundaries and assumed a future migration requirement. Because Routina had no released user data requiring compatibility, that assumption preserved more states than the product actually supported. Mechanical replacements then risked applying old kind-specific behavior to every Routine.

## Fix

The domain and persistence schema now contain only Routine and Todo kinds. Compatibility schedule modes, storage aliases, visibility fields, import fallbacks, help entries, and dedicated tests were removed. Remaining routine behavior was reviewed semantically instead of mapping every old branch to Routine. Task configuration was then regrouped around the real concepts that remain.

## Prevention Rule

For an unreleased feature with no data-compatibility obligation, retirement is a whole-stack deletion: domain cases, persistence and cloud schema, migration/import aliases, UI, help, documentation, fixtures, and tests must agree on the smaller state space. Do not translate a removed case into a surviving case unless the behavior is independently valid for that case.

## Regression Safeguard

Model and presentation tests assert that only Routine and Todo exist. Form layout tests protect the unified Behavior & Schedule, Task Ladder values, and Organization groups. Task Detail layout tests protect the always-visible four-value container, and help tests cover only current Changes over time guidance.

This follow-up completes the cleanup begun in [0229](0229-keep-retired-task-types-out-of-active-guidance.md), which correctly removed stale user guidance but retained a compatibility layer that was later shown to be unnecessary.
