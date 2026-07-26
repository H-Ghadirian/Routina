# 0040 — Retire product concepts across all presentation surfaces

Date: 2026-07-26

## Symptom

After the task form removed the Tracking choice, Home and Timeline filters,
Stats, Settings rules, badges, and sidebar presentation still exposed Tracking
as a distinct task type.

## Root Cause

The creation control and the downstream presentation enums evolved
independently. Removing the entry point did not remove the product concept from
filters, reports, customization, or compatibility sections.

## Fix

User-facing task categories now contain only Routines and Todos. Internal
record-shaped tasks are folded into routine presentation and statistics, while
Tracking-only filters, sections, Settings rules, labels, and Stats cards are
removed.

## Prevention Rule

When retiring a product concept, audit every presentation boundary: creation,
editing, filtering, search vocabulary, list placement, badges, empty states,
statistics, customization, persistence restoration, and platform-specific
surfaces. An internal storage case must not automatically remain a visible
product category.

## Regression Safeguard

Task-form, Home-filter, Timeline-filter, Stats-filter, custom-section storage,
task-list placement, and dashboard-availability tests assert the reduced
Routines/Todos surface and verify that internal record-shaped tasks are handled
as routines.
