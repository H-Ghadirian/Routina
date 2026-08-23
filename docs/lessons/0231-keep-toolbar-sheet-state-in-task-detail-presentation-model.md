# 0231 — Keep toolbar sheet state in the task-detail presentation model

Date: 2026-08-23

## Symptom

The iOS Task Detail Add-a-detail chevron could appear normally but do nothing
when Task Details was hosted by some navigation screens.

## Root Cause

Edit and maintenance presentations were routed through `TaskDetailFeature`, but
the newer Add-a-detail toolbar button alone called back into view-local sheet
state. SwiftUI can rehost toolbar content independently of the detail view that
created that callback, leaving the visible button detached from the sheet host.
The button also declared a smaller target than Routina's standard 44-point iOS
control surface.

## Fix

Task Detail now owns Add-a-detail presentation in `TaskDetailFeature.State`,
opens and closes it through reducer actions, and binds the sheet through the
shared presentation router. The chevron label fills a 44-by-44-point target.

## Prevention Rule

Route sheet state for navigation-bar and toolbar controls through the stable
feature presentation model used by every host. Do not make shared toolbar
content depend on a callback into one host view's local presentation state.

## Regression Safeguard

`TaskDetailFeatureTests` verifies the presentation action, and
`TaskDetailPlatformActionParityTests` protects the reducer-routed toolbar and
44-point target. `RoutinaUITests` taps the chevron from Home and Timeline Task
Details, and the iOS Task Detail maintenance scenario covers compact and regular
layouts.
