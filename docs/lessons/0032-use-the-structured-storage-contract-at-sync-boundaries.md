# 0032 — Use the structured-storage contract at sync boundaries

Date: 2026-07-26

## Symptom

Direct CloudKit pull could silently downgrade Advanced recurrence to its simplified compatibility columns. Hourly daily-window recurrence became a basic daily interval, and monthly ordinal recurrence became a single month-day rule.

## Root Cause

The model layer treats serialized recurrence as authoritative whenever `requiresStructuredStorage` is true, but the CloudKit parser used the narrower `hasMultipleCalendarSelections` condition. That preserved simple multi-selection rules while excluding Advanced rules without multiple top-level weekdays or month dates.

## Fix

CloudKit direct pull now prefers a successfully decoded serialized recurrence whenever it requires structured storage. Scalar typed columns remain authoritative for ordinary Simple rules that they can fully represent.

## Prevention Rule

Every persistence, backup, import, and sync boundary must use the domain model's complete structured-storage predicate when choosing between a lossless payload and compatibility fields. Do not recreate that predicate from one subset of structured cases.

## Regression Safeguard

`CloudKitDirectPullRecurrenceTests` verifies that both hourly daily-window and monthly ordinal Advanced rules survive records containing competing scalar compatibility columns, while the existing typed-column test continues to protect Simple recurrence.
