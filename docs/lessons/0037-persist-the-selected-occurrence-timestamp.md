# 0037 — Persist the selected occurrence timestamp

Date: 2026-07-26

## Symptom

Task Detail could validate a deliberately selected historical exact-time occurrence, while persistence recomputed the routine's next due occurrence and recorded a different timestamp.

## Root Cause

Selection validation and persistence each resolved the completion target independently. The reducer passed the selected scheduled timestamp, but `RoutineLogHistory.advanceTask` replaced every Advanced completion timestamp with a newly derived due date.

## Fix

Exact-time Advanced completion now preserves a supplied timestamp when it matches a generated occurrence. The occurrence selector routes its selected timestamp through that same path, while non-exact Advanced completion keeps the existing due-date derivation.

## Prevention Rule

Once an action has validated an explicit occurrence identity, persistence must either record that identity or reject the action. It must not silently substitute another occurrence.

## Regression Safeguard

`RoutineLogHistoryTests.advanceTaskPersistsTheExplicitlySelectedSubdailyOccurrence` verifies that selecting the later of two same-day occurrences records the later timestamp. Task Detail presentation tests verify occurrence selection, independent state, and reset when the selected calendar day changes. Decision [0434](../decisions/0434-select-subdaily-occurrences-in-task-detail.md) defines the user-facing contract.
