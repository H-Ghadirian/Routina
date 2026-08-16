# 0183 — Check derived state before progress shortcuts

Date: 2026-08-16

## Symptom

Home showed a one-off task as `In Progress` while Task Details correctly showed
it as `Blocked` by an unfinished linked prerequisite.

## Root Cause

The shared row badge presenter checked its generic ongoing shortcut before the
relationship-derived Todo state. A one-off task carrying ongoing presentation
state therefore returned `In Progress` before the cached blocker flag could
replace that stored progress state with `Blocked`.

## Fix

The relationship-derived Blocked check now runs after stronger paused and away
row presentation but before the generic ongoing and step-progress shortcuts.
Completed and canceled one-off tasks retain their existing precedence.

## Prevention Rule

Evaluate derived effective state before generic presentation shortcuts for any
stored state that the derivation is defined to replace. A regression for Ready
or stored In Progress is incomplete if another earlier branch can render the
same visible label.

## Regression Safeguard

`HomeTaskListFilteringTests` includes a one-off task that is both ongoing and
relationship-blocked and requires the shared presenter to return `Blocked`.
The Home and Task Detail State Reflect Unresolved Prerequisites scenario states
that ongoing row presentation cannot override the effective Blocked state.
