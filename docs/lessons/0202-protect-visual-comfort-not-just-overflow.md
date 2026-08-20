# 0202 — Protect visual comfort, not just overflow

Date: 2026-08-18

## Symptom

The Mac Planner still showed expanded Calendar, Schedule/List, Day/3 Days/Week, Focus, navigation, and textual `Go to date` controls in a Week layout the user identified as too tight.

## Root Cause

The compact fallback used measured overflow plus the spare-width reserve added in [0201](0201-switch-compact-headers-before-space-is-exhausted.md). That protected against clipping, but it still treated a visually crowded full Calendar header as acceptable when the controls technically fit.

## Fix

The Calendar header now also requires a comfortable overall expanded-header width before it uses full segmented controls. Below that width, the Calendar control set switches to current-value menus and `Go to date` becomes icon-only. Timeline mode remains governed by measured fit because it does not show the full Calendar control set.

## Prevention Rule

Dense toolbars need both a fit threshold and a comfort threshold. If a layout contains several independent controls, do not define success as "no overflow" alone.

## Regression Safeguard

`DayPlanPlannerStateTests.plannerHeaderUsesCompactControlsWhenTheCalendarRowIsVisuallyCrowded` covers the comfortable-width boundary, and `Tests/macOS/PerformanceRegressionTests.swift` guards the source-level constant and Calendar-only application. [0203](0203-remeasure-after-optional-header-controls-appear.md) extends this lesson for loaded optional controls and optimistic parent widths. The behavior is recorded in [Decision 0612](../decisions/0612-require-comfortable-width-for-expanded-planner-header.md) and the Planner header scenarios.
