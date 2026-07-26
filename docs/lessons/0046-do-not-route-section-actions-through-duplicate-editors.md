# 0046 — Do not route section actions through duplicate editors

Date: 2026-07-27

## Symptom

In Mac Task Details, clicking `Link a Task` inside an already-visible Linked
Tasks section inserted a second Linked tasks editor below it. The user then had
to click the duplicate editor's `Link a Task` button before the existing-task
picker opened.

## Root Cause

The visible section's action reused the generic `Add more details` path,
`revealInlineEditSection(.linkedTasks)`. That path is intended to reveal a
missing optional section, not to execute an action owned by a section that is
already visible.

## Fix

The visible `Link a Task` action now presents the existing-task picker directly.
Selecting a task dispatches a focused Task Detail relationship mutation that
persists only the new link and keeps the existing Linked Tasks section in
place.

## Prevention Rule

When an action is rendered inside an existing section, route it directly to its
destination or mutation. Use optional-section reveal paths only when the
section is absent; never reveal a second editor as an intermediate step for an
action the visible section already owns.

## Regression Safeguard

`TaskDetailSharedViewSupportTests` verifies that the first-click action presents
the picker and does not call the inline-section reveal path.
`TaskDetailEditSaveTests` verifies that picker selection persists the
relationship without opening Edit Task. The Mac linked-task regression scenario
also forbids a duplicate Linked Tasks editor and second action click.
