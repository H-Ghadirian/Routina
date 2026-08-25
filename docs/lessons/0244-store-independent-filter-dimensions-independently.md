# 0244 — Store independent filter dimensions independently

Date: 2026-08-24

## Symptom

Mac Timeline displayed separate Type and Status controls, but choosing one
silently reset the other.

## Root Cause

Both controls projected different subsets of one `TimelineFilterType` value,
so the state model could represent a type or an outcome status, never both.

## Fix

Timeline now stores a separate persisted `TimelineStatusFilter`, combines it
with content Type by intersection, and migrates legacy outcome selections.

## Prevention Rule

Controls presented as independent dimensions must own independently
representable state and tests must cover their combined selection.

## Regression Safeguard

`Tests/Shared/TimelineLogicTests.swift`,
`Tests/Shared/HomeFilterEditorTests.swift`, and the Mac source regression tests
cover combined filtering, persistence, migration, and independent bindings.
