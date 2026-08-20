# 0212 — Show saved reminders in Task Details

Date: 2026-08-20

## Symptom

A one-off task could have a saved reminder, but the person had to open Edit Task to verify the reminder time from the Task Details overview.

## Root Cause

Task Detail state already derived `reminderMetadataText`, and the header badge presentation already had reminder data, but the shared status metadata presentation did not include a reminder row. The overview therefore omitted a direct, scannable reminder value.

## Fix

Added a `Reminder` status metadata row with the saved date/time and bell icon for one-off tasks that have a reminder. Updated the current-behavior, user-experience, and scenario documentation.

## Prevention Rule

When Task Detail state exposes meaningful saved metadata, include it in the shared status presentation used by every platform overview unless a documented progressive-disclosure rule intentionally hides it.

## Regression Safeguard

`TaskDetailSharedViewSupportTests.statusMetadataShowsSavedOneOffReminder` asserts that a saved reminder makes status metadata visible and produces the expected labeled row, value, and icon.
