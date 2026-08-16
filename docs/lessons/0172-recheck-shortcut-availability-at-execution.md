# 0172 — Recheck shortcut availability at execution

Date: 2026-08-16

## Symptom

On iOS, shaking the device could still reach the Sleep-mode confirmation or
start path after the Sleep feature or shake shortcut had been turned off in
Settings.

## Root Cause

The SwiftUI background checked the shake preference only when deciding whether
to mount the UIKit motion-event bridge. The bridge callback and confirmation
action did not re-check current feature availability, and bridge teardown did
not explicitly clear its callback or resign first responder. A stale callback
or already-presented confirmation could therefore outlive the setting that had
made it available.

## Fix

One availability policy now requires Away, the Sleep experiment, the shake
shortcut, and no active Sleep session. The bridge, shake callback, and final
start action all use that policy. Losing availability dismisses any pending
confirmation, while bridge teardown clears the callback and resigns first
responder.

## Prevention Rule

For feature-gated hardware shortcuts, gate both presentation and effect
execution with the current settings. Teardown the platform event source, and
invalidate any pending confirmation when availability changes.

## Regression Safeguard

`SleepSessionSupportTests.shakeStartAvailability_requiresSleepFeatureAndShortcutFlags`
protects the availability matrix.
`IOSNewTabActionAvailabilityTests.shakeSleepRechecksAvailabilityBeforeConfirmationAndStart`
guards callback, confirmation, and UIKit teardown wiring. The iOS New Actions
scenario records the end-to-end expectation.
