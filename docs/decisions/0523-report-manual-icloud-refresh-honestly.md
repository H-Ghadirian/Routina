# 0523: Report Manual iCloud Refresh Honestly

Status: Accepted

Date: 2026-08-09

Refines: [0167 Merge iCloud and Backup Settings](0167-merge-icloud-and-backup-settings.md)

## Context

`Sync Now` saves local SwiftData changes and completes a direct CloudKit download into the local store. Core Data's device-to-server export is scheduled separately by the system, so a successful download cannot prove that queued local uploads also succeeded.

## Decision

While the manual operation is running, the iCloud & Backup status says that Routina is checking iCloud for updates. A successful direct pull confirms only that the latest iCloud data was received and states that local changes continue syncing in the background. The app must not report a full sync as completed unless CloudKit has recorded a successful export.

Support diagnostics remains the source for the last confirmed CloudKit import or export result, including any failure details.

## Consequences

- Users receive an accurate, actionable status instead of a false success message.
- A background export failure remains visible for support without making the manual download appear to have failed.
- The wording works on iOS and macOS while preserving the platform-managed Core Data + CloudKit sync model.
