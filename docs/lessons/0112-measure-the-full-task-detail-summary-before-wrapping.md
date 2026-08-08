# 0112 — Measure the full task-detail summary before wrapping

Date: 2026-08-08

## Symptom

In the macOS task-detail companion pane, a task with a short title and a long completion action could leave the status explanation in a narrow column and create a large empty area in the header card.

## Root Cause

The adaptive header measured only the title when deciding whether to move the action cluster onto its own row. A short title therefore kept the horizontal layout even when the accompanying status text had too little usable width. The header card also did not explicitly take the pane's available width before its children chose their layout.

## Fix

The header now measures its complete summary content—title, breadcrumb, and status message—against the action cluster, and its root stack expands to the available width. When those elements do not fit together, the cluster moves above the full-width summary.

## Prevention Rule

For adaptive headers, choose the layout from every visible summary element that shares the constrained row, not from the title alone. Establish the container width before measuring that row.

## Regression Safeguard

`PerformanceRegressionTests.testTaskDetailHeaderStacksItsFullSummaryAwayFromActionCluster` checks the full-summary measurement, width claim, and stacked action layout in `TaskDetailHeaderSectionView`.
