# 0023 — Derive Stats comparisons from range duration

Date: 2026-07-25

## Symptom

A custom Stats range containing exactly one day displayed redundant multi-day comparisons, including Daily average, Best day, active-day badges, and trend charts.

## Root Cause

Stats presentation code inferred whether comparisons were meaningful by checking if the selected range was the `Today` preset. A one-day custom range has different range identity even though its inclusive duration is also one day.

## Fix

Stats now gates multi-day comparisons on the selected range's inclusive day count across shared hero and summary presentation, dashboard availability, and iOS and macOS Git contribution sections.

## Prevention Rule

When presentation depends on a range's duration, derive it from normalized range boundaries or inclusive day count rather than from the preset identity.

## Regression Safeguard

Shared Stats tests verify that a one-day custom range omits comparison cards while a multi-day custom range retains them.
