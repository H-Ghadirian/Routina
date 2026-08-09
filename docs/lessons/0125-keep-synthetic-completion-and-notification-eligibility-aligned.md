# 0125 — Keep Synthetic Completion and Notification Eligibility Aligned

Date: 2026-08-09

## Symptom

An auto-assumed task such as `Brush Teeth` still delivered a due notification
when its scheduled availability window opened.

## Root Cause

The notification coordinator evaluated archive state and scheduling cadence,
but not the same auto-assume eligibility that marked the occurrence
synthetically complete.

## Fix

Task notification scheduling now returns ineligible when active auto-assume
behavior applies.

## Prevention Rule

Whenever a task is represented as synthetically complete, every task-action
surface must use that same eligibility rule before prompting the person to
act.

## Regression Safeguard

`NotificationCoordinatorTests.shouldScheduleNotification_returnsFalseForAutoAssumedRoutine`
uses the 21:00–03:00 `Brush teeth` schedule that exposed the defect. Scenario
coverage is recorded in `docs/scenarios/README.md`.
