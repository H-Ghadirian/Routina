# 0087 — Deduplicate planner block records before rendering

Date: 2026-08-06

## Symptom

Opening the app could crash in `DayPlanBlockLayer` with a duplicate
`planned-focus` key when Planner received two persisted blocks with the same ID.

## Root Cause

`DayPlanStorage` sanitized individual values but did not enforce one block per
ID within a day. Duplicate SwiftData records could therefore reach the Calendar
placement dictionary, which intentionally requires unique render identities.

## Fix

Day-plan loading and saving now collapse same-ID records to the most recently
updated block. Saving the sanitized result also removes the stale SwiftData
record.

## Prevention Rule

Any persisted collection whose IDs are used as render or layout keys must
deduplicate those IDs at its storage boundary before reaching SwiftUI.

## Regression Safeguard

`DayPlanStorageTests.loadingDuplicateBlockRecordsUsesTheMostRecentlyUpdatedBlockAndRepairsOnSave`
creates duplicate records, verifies one safe loaded block, and verifies that a
subsequent save repairs persistence.
