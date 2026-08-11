# 0145 — Own iOS filter details at stable sheet roots

Date: 2026-08-11

## Symptom

Opening a detail picker from the Home, Stats, or Timeline iOS Filters sheet
could immediately dismiss the picker after it appeared.

## Root Cause

Each filter row or `List` section owned its own nested sheet state. Updating
SwiftUI during presentation could recreate that transient row host, reset its
local presentation binding, and dismiss the detail sheet.

## Fix

Home, Stats, and Timeline filter-sheet roots now own an identifiable filter
detail destination and present each nested picker from that stable root. Rows
only request the appropriate destination.

## Prevention Rule

Never attach nested sheets to a conditional or collection-backed filter row.
Keep presentation state and the sheet modifier on the stable filter-sheet root.

## Regression Safeguard

`TaskFormIOSLayoutRegressionTests` verifies that Home, Stats, and Timeline use
root-owned detail destinations, while `HomeIOSTaskTypeSegmentLayoutTests`
continues to cover the relocated picker layouts.
