# 0258 — Preserve accepted toolbar control silhouettes

Date: 2026-08-27

## Symptom

After Focus moved into the Mac action menu, a follow-up restyle made both the
workspace and add controls look worse to the person. When a timer was already
running, Focus was greyed out without a visible explanation in the open menu.

## Root Cause

The follow-up changed already accepted compact toolbar silhouettes and hid
native menu affordances to solve local alignment concerns. It also treated
hover help and the separate status menu as sufficient explanation for a
disabled action, even though neither was visible at the decision point.

## Fix

The workspace menu and rounded `+` trigger return to their earlier
presentations. A competing timer adds `Another timer is running` beneath the
disabled Focus row, and the existing live timer badge is shown beside the Home
sidebar toggle so its controls remain directly reachable.

## Prevention Rule

Preserve an accepted toolbar control's recognizable silhouette when changing
what it does. If an action is disabled by recoverable app state, explain that
state in the same open surface and keep the state-management route visible.

## Regression Safeguard

The Mac New-menu scenario now covers the restored trigger, competing-timer
message, and leading live timer. `Tests/macOS/HomeFeatureTests.swift` protects
the active-timer availability predicate, while
`Tests/macOS/PerformanceRegressionTests.swift` protects the compact trigger,
visible explanation, and timer-badge placement.
