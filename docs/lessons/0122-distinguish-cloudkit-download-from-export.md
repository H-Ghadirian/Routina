# 0122 — Distinguish a CloudKit download from an export

Date: 2026-08-09

## Symptom

After `Sync Now` showed “Sync completed,” Support diagnostics could still show a failed CloudKit export.

## Root Cause

The manual operation verifies a direct server-to-device download. SwiftData and Core Data schedule device-to-server exports independently, but the UI treated the completed download as proof that the asynchronous export had also succeeded.

## Fix

The iCloud status now identifies the operation as checking iCloud for updates. On success it confirms that the latest iCloud data was received and says local changes continue syncing in the background; it does not claim a full sync completed.

## Prevention Rule

Never use a completed CloudKit pull to certify a queued Core Data export. Only an observed successful export event may confirm that this device's outgoing changes reached CloudKit.

## Regression Safeguard

`SettingsFeatureTests.syncNow_reportsTheVerifiedDownloadWithoutClaimingBackgroundUploadsSucceeded` protects the exact status contract. The matching scenario is recorded in `docs/scenarios/README.md`.
