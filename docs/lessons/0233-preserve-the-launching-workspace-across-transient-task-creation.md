# 0233 — Preserve the launching workspace across transient task creation

Date: 2026-08-23

## Symptom

Canceling Mac Add Task after opening it from Backlog showed Planner instead of returning to Backlog.

## Root Cause

Add Task replaced the active workspace with a transient navigation mode, but the reducer did not retain the workspace that launched it. The cancel handler therefore used Planner as a hard-coded fallback for every launch context.

## Fix

Mac navigation now records the launching workspace when it enters Add Task and restores that workspace on Cancel. The launching workspace is also persisted as the relaunch destination while the transient form is open. A successful full-form save still selects the new task in Planner.

## Prevention Rule

When a transient workspace temporarily replaces a durable workspace, store its explicit return destination before the transition and clear it when the transient flow ends. Do not reconstruct return navigation from a universal default.

## Regression Safeguard

`Tests/macOS/HomeFeatureAddRoutinePresentationTests.swift` opens Add Task from Backlog, verifies Backlog remains the persisted relaunch destination, cancels, and verifies Backlog is restored. The workflow is also recorded in `docs/scenarios/README.md`.
