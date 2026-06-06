# 0167 Merge iCloud and Backup Settings

- Status: Accepted
- Date: 2026-06-06
- Refines: [0165 Suggest Backup Before Cloud Data Reset](0165-suggest-backup-before-cloud-data-reset.md), [0166 Use App Lock for Cloud Data Reset](0166-use-app-lock-for-cloud-data-reset.md)

## Context

iCloud sync, iCloud deletion, and local backup/import are all data-continuity controls. Keeping iCloud and Data Backup as separate Settings destinations makes the recovery action feel separate from the destructive cloud reset flow, even though reset already asks users to back up first.

## Decision

Merge iCloud and Data Backup into one Settings section named iCloud & Backup. The combined destination contains iCloud sync/reset controls, backup export/import controls, status for both operations, and the iCloud usage estimate. Hide the legacy Data Backup section from Settings navigation, but keep its enum case and route persisted Backup selections to the combined iCloud & Backup destination.

## Consequences

- Data safety and recovery actions sit beside cloud sync and reset controls.
- Settings has one fewer visible section on iOS, iPadOS, and macOS.
- Existing persisted navigation state that points at Data Backup opens the merged destination instead of falling back to an unrelated section.
