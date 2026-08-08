# 0107 — Name Repeatable Cadence-Free Completions

Date: 2026-08-08

## Symptom

After completing a cadence-free routine, iOS continued to show an unchanged `Done` button even though the task was deliberately available for another history entry.

## Root Cause

The generic Task Detail completion title only distinguished terminal and cadence-governed completions. It intentionally left cadence-free routines actionable, but provided no iOS-specific copy to distinguish a new entry from an initial completion.

## Fix

iOS now detects a cadence-free routine with a completion on the selected current day and labels its action `Log another completion` with a plus symbol. The underlying repeatable-history behavior is unchanged.

## Prevention Rule

When an action stays enabled after it changes the task state, update its visible label or state so people can tell whether they are repeating the action or performing it for the first time.

## Regression Safeguard

`TaskDetailIOSCompletionPresentationTests` verifies both the follow-up completion label and the initial `Done` state for cadence-free routines.
