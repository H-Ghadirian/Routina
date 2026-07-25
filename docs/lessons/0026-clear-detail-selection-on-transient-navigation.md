# 0026 — Clear detail selection on transient navigation

Date: 2026-07-25

Revised by [0027](0027-preserve-detail-across-transient-add-task.md), which preserves the selected detail while suppressing only return-time task-list alignment.

## Symptom

Opening Add Task from an existing task detail and then returning to Tasks unexpectedly changed the left task list to a task-type tab and restored an old filter such as `Yesterday`.

## Root Cause

Entering the transient Mac Add Task mode cleared `macSidebarSelection` but retained the selected task and task-detail state. Returning to Tasks interpreted that hidden selection as active navigation intent, aligned the task-list mode to the old task, and restored that mode's saved filter snapshot.

## Fix

Entering Add Task now clears the task selection and task-detail state together with the visible sidebar selection.

## Prevention Rule

When transient navigation replaces a selected detail surface, clear both platform navigation selection and shared domain detail selection unless the return path explicitly promises selection restoration.

## Regression Safeguard

The Mac Home feature test opens Add Task from a selected routine, returns to Tasks, and verifies that the prior `All` mode and unfiltered created-date state remain unchanged. The workflow is also recorded in `docs/scenarios/README.md`.
