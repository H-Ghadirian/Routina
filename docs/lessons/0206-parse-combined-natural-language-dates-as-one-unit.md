# 0206 — Parse combined natural-language dates as one unit

Date: 2026-08-20

Refined by: [0208 — Preserve the meaning of parsed task dates](0208-preserve-the-meaning-of-parsed-task-dates.md)

## Symptom

Entering `Physiotherapist Tuesday, 25 August 15:00` in Smart Add or the Mac search-or-create field left the date and time in the task title instead of recognizing scheduling metadata.

## Root Cause

The shared parser recognized only relative todo dates (`today`, `tomorrow`, and prefixed weekdays). It had no grammar for a concrete day-month date with an optional weekday, and its 24-hour time grammar required the word `at`.

## Fix

Quick Add now parses English day-month dates with an optional weekday and year, resolves a missing year to the nearest matching occurrence, and accepts a standalone 24-hour time. The parsed date and time become the one-off deadline and reminder while the remaining text becomes the task name.

## Prevention Rule

Treat a user-reported natural-language capture phrase as a complete grammar case. Test the cleaned title and every derived field together so recognizing one token cannot conceal that the surrounding date phrase was left unparsed.

## Regression Safeguard

`RoutinaQuickAddParserTests.parseWeekdayDayMonthAndBare24HourTimeAsTodoDeadline` protects the exact reported phrase, and the Quick Add explicit-date scenario records the cross-platform expectation.
