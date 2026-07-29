# 0069 — Do not inherit fixed preference-window capabilities

Date: 2026-07-29

## Symptom

The Mac Settings window showed disabled minimize and zoom buttons and could not
be resized or entered into full screen.

## Root Cause

SwiftUI's dedicated `Settings` scene applied traditional preference-panel
window capabilities. Giving the root content only a minimum frame did not
override the native window's style mask, maximum size, button state, or
full-screen collection behavior.

## Fix

The Settings scene now uses content-minimum resizability and configures its
attached `NSWindow` to be miniaturizable, resizable, zoomable, and a primary
full-screen window while retaining the existing minimum content size.

## Prevention Rule

When a SwiftUI scene requires standard desktop window behavior, verify the
resulting native window capabilities; content frame constraints alone do not
guarantee minimize, zoom, resize, or full-screen support.

## Regression Safeguard

`PerformanceRegressionTests.testMacSettingsWindowKeepsStandardWindowActionsAvailable`
guards the declarative resizability and native window capability configuration.
The matching behavior is recorded in `docs/scenarios/README.md`.
