# 0127 — Keep desktop sheet minimum sizes out of iOS presentations

Date: 2026-08-10

## Symptom

The iOS Link Task sheet was wider than a compact iPhone screen, causing its
left edge and controls to be clipped and the task list to appear stretched.

## Root Cause

The shared task-relationship picker applied a 520-point minimum width for its
macOS sheet without restricting that desktop constraint to macOS.

## Fix

The picker now applies its 520-by-420 minimum frame only when built for macOS.
iOS lets the system size the sheet to the available device width.

## Prevention Rule

Keep fixed or minimum window dimensions in platform-specific branches whenever
a shared SwiftUI view can be presented on compact iOS devices.

## Regression Safeguard

`TaskFormIOSLayoutRegressionTests.linkTaskPickerKeepsDesktopMinimumSizeOutOfIOSSheets`
checks that the Link Task picker keeps its desktop minimum frame behind its
macOS compilation guard.
