# 0273 — Derive each toolbar control from its capability

Date: 2026-08-30

## Symptom

An empty iOS Stats dashboard still showed Cards/Compact, Edit, and Filter. Edit
opened a mode containing disabled Add and Reset actions, while the other
controls had no content they could affect.

## Root Cause

The three toolbar controls were installed unconditionally. Reportability
already governed dashboard sections, but the toolbar did not consume that
availability and treated unrelated controls as permanent page chrome.

## Fix

iOS Stats now derives each toolbar action independently. Summary mode requires
a visible summary item, editing requires a reportable dashboard item, and
filtering requires task data or an active sheet-filter recovery path. Losing
reportable items also closes edit mode and its Add sheet.

## Prevention Rule

Derive optional toolbar controls from the exact capability they act on, not
merely from page presence or a shared group condition. Preserve explicit
recovery paths for hidden content and active state while omitting inert chrome.

## Regression Safeguard

The iOS Stats toolbar scenario covers genuinely empty, hidden-item,
active-filter, chart-only, and disappearing-data states.
`StatsDashboardToolbarAvailabilityTests` verifies the independent availability
rules.

Related decision: [0700 — Hide Inert iOS Stats Toolbar Controls](../decisions/0700-hide-inert-ios-stats-toolbar-controls.md).
