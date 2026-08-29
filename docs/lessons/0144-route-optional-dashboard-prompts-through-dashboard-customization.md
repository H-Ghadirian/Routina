# 0144 — Route optional dashboard prompts through dashboard customization

Date: 2026-08-11

## Symptom

The optional Connect Apple Health card appeared in iOS Stats but had no remove
control in Edit mode, despite the surrounding dashboard sections being
removable.

## Root Cause

The card rendered before the dashboard's ordered item blocks, rather than
being represented as a dashboard item. It therefore bypassed the shared
visibility, restore, and editing behavior.

## Fix

Represented the Apple Health access prompt as a conditional Stats dashboard
item. It now receives the standard remove control and appears in Add to Stats
when hidden and still relevant.

## Prevention Rule

Every optional Stats surface that users may reasonably dismiss must participate
in the same dashboard-item model that owns visibility and restoration; do not
place it beside that model as a fixed card.

## Regression Safeguard

The original Apple Health safeguards were retired when the integration was
removed. The general prevention rule remains applicable to future optional
dashboard prompts.

## Current Applicability

[Decision 0697](../decisions/0697-omit-apple-health-from-the-first-release.md)
removed the Apple Health prompt and superseded
[Decision 0550](../decisions/superseded/0550-make-apple-health-stats-prompt-dismissible.md).
