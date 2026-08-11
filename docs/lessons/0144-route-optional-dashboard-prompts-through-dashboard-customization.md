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

`StatsDashboardItemAvailabilityTests.healthAccessPrompt_isDashboardItem` and
`IOSStatsDashboardPresentationTests.healthAccessPromptCanBeRemovedFromIOSStats`
guard the item registration and its editable iOS render path. The expected
behavior is documented in `docs/scenarios/README.md` and Decision
[0550](../decisions/0550-make-apple-health-stats-prompt-dismissible.md).
