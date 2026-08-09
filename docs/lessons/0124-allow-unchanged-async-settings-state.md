# 0124 — Allow unchanged async Settings state

Date: 2026-08-09

## Symptom

The CloudKit `Sync Now` test failed when an empty store correctly produced a zero iCloud usage estimate.

## Root Cause

The test required the received zero estimate to mutate Settings state that was already zero. The reducer action is still required, but no state change is expected in that valid case.

## Fix

The test now verifies that it receives the zero estimate without asserting a redundant state mutation.

## Prevention Rule

Reducer tests must distinguish verifying that an asynchronous action arrived from verifying that it changes state. Do not require a state mutation when the received value can validly equal the existing state.

## Regression Safeguard

`SettingsFeatureTests.syncNow_reportsTheVerifiedDownloadWithoutClaimingBackgroundUploadsSucceeded` now covers the empty-store synchronization path and accepts its zero usage estimate.
