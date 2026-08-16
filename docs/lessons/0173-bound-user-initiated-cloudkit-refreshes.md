# 0173 — Bound user-initiated CloudKit refreshes

Date: 2026-08-16

## Symptom

iOS Settings could remain on `Checking iCloud for updates...` for minutes after
selecting `Sync Now`. iOS Home pull-to-refresh waited on the same operation and
could leave its refresh indicator active just as long.

## Root Cause

Both surfaces awaited one direct full-zone `CKFetchRecordZoneChangesOperation`
without setting an interactive resource deadline or propagating Swift task
cancellation into the CloudKit operation. CloudKit's default whole-resource
timeout is seven days, and Home discarded errors, so large, throttled, weak-
network, or stalled requests had no useful product-level terminal state.

## Fix

The explicit full-zone pull now uses a 60-second request/resource timeout, an
independent watchdog, and cancellation-safe one-time continuation completion.
Settings and Home share actionable error wording. Home ends refresh, reloads
local data, and offers retry; Settings ends progress and leaves `Sync Now`
available. The fetch still merges only after a complete successful response.

## Prevention Rule

Every user-awaited platform operation must have an app-owned deadline,
propagate task cancellation to the underlying API, and give every visible
progress state a success or recoverable failure transition. Do not rely on a
framework's server-operation defaults for an interactive spinner.

## Regression Safeguard

`CloudKitSyncDiagnosticsTests.manualRefreshOperationUsesIdleAndHardSafetyLimits`
protects the CloudKit operation configuration.
`SettingsFeatureTests.syncNow_stalledPullStopsProgressAndExplainsRecovery` protects
the Settings terminal state.
`HomeFeatureLifecycleEffectSupportTests.manualRefreshFailureReportsRecoveryAndStillReloadsLocalData`
protects Home error feedback and local reload behavior. The Manual iCloud
Refresh scenario records the cross-surface expectation.

Follow-up: [0175](0175-distinguish-cloudkit-stalls-from-progress.md) revises the
timeout model to distinguish inactivity from a legitimately progressing pull.
