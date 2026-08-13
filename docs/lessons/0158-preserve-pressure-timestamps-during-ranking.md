# 0158 — Preserve pressure timestamps during ranking

Date: 2026-08-13

## Symptom

A manual reorder within one Pressure value section could make that task appear
as though its Pressure value had just been edited.

## Root Cause

The ranking mutation reapplied the selected metric value for every move. The
`RoutineTask.pressure` setter intentionally updates `pressureUpdatedAt`, even
when the incoming value equals the persisted one.

## Fix

Task Ladder now writes Pressure only when a cross-section move actually changes
the pressure value. A within-section reorder writes only the task-ranking key.

## Prevention Rule

Keep ordering mutations separate from metadata mutations. When a model setter
has timestamp or other side effects, guard against assigning an unchanged value
from an ordering path.

## Regression Safeguard

`TaskRankingPresentationTests.reorderingWithinPressureDoesNotRefreshItsValueTimestamp`
asserts that a same-section Pressure move preserves `pressureUpdatedAt`.
