# 0072 — Choose a window host that supports required capabilities

Date: 2026-07-29

## Symptom

The Mac Settings window could minimize and resize after its traffic-light and
style flags were changed, but it still could not enter native full screen.

## Root Cause

SwiftUI's special `Settings` scene retained preference-panel hosting policy.
Changing the attached `NSWindow` flags altered visible controls without
changing the host's actual full-screen capability.

## Fix

Settings now uses a standard single-instance `Window` scene. Routina recreates
the system Settings menu command and Command-comma routing with `openWindow`,
while suppressing the window at launch and preserving its content minimum.

## Prevention Rule

Choose a SwiftUI scene type whose native host already supports every required
window capability. Do not treat enabled traffic-light buttons or a modified
style mask as proof that a restricted scene can perform the corresponding
window transition.

## Regression Safeguard

`MacSettingsWindowPresentationTests` and
`PerformanceRegressionTests.testMacSettingsUsesAStandardFullscreenWindowWithSystemCommandRouting`
guard the standard Window host, the absence of the special Settings scene,
launch suppression, and the restored Settings command and shortcut.
