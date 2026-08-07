# 0093 — Keep task-list Flags in the task-list filter pane

Date: 2026-08-07

## Symptom

The Mac Task List filter pane did not show Flag filters. Its only visible
section was also collapsed on entry, requiring an extra click before people
could use the ordinary filters.

## Root Cause

The task-list pane intentionally hides the shared Tags section because tags
belong to the `All` filter scope. The task-only Flag view had been attached to
that hidden section, so it inherited the tag gate. The separate core Filters
card used the generic collapsible component even when it was the only card.

## Fix

The core Task List Filters card is now permanently visible. Flag controls are
rendered inside that card only when assigned Flag options exist, independent of
the shared Tags section.

## Prevention Rule

Do not attach a task-list-only control to a shared-filter visibility gate. A
single mandatory filter card should show its controls directly instead of
requiring a disclosure action.

## Regression Safeguard

The Mac filter-pane source regression check verifies that the core card is not
collapsible and that the task-list Flag controls are routed through their own
visibility condition.
