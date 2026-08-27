# 0257 — Gate global actions from domain eligibility

Date: 2026-08-27

## Symptom

The Mac global New menu could show Focus as disabled even though an active task
was still eligible for the Focus sheet.

## Root Cause

The new global menu reused a Planner-era display-count gate. A Home display
count describes the current presentation and can become empty because of
loading, filtering, or placement, while Focus availability depends on the
separate eligible-task snapshot used to build its sheet.

## Fix

The Focus menu availability now checks the same eligible Focus-task snapshot
that the sheet receives. Active Focus and sprint timers remain independent
blocking conditions.

## Prevention Rule

Gate a global domain action from the domain inputs that action will consume.
Do not substitute a screen's visible-row or presentation count unless
visibility itself is part of the action's documented eligibility contract.

## Regression Safeguard

`Tests/macOS/HomeFeatureTests.swift` covers the Focus availability states, and
`Tests/macOS/PerformanceRegressionTests.swift` requires the Mac toolbar route
to use `homeToolbarFocusStartTasks` rather than a Home display count.
