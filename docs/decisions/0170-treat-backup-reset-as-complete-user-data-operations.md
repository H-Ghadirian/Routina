# 0170 Treat Backup and Reset as Complete User Data Operations

- Status: Accepted
- Date: 2026-06-06
- Refines: [0167 Merge iCloud and Backup Settings](0167-merge-icloud-and-backup-settings.md), [0168 Require Recent Backup for Cloud Data Reset](0168-require-recent-backup-for-cloud-data-reset.md)

## Context

Routina has accumulated several SwiftData-backed user domains beyond tasks, goals, places, and logs, including focus sessions, planner blocks, board records, device sessions, notes, events, emotions, sleep, away, and place check-ins. Backup and destructive reset flows can silently become incomplete if each new model is added only to the main `ModelContainer`.

## Decision

Treat Routina backup/import and destructive cloud/local reset as complete user-data operations. The package backup schema must include every SwiftData user model that belongs to the primary app data store, and import must restore those records with their relationships filtered to records present in the same backup. Destructive reset must wipe the same local SwiftData user model set and remove user-owned CloudKit records from Routina's private CloudKit zones.

Legacy `.json` backup remains a compatibility path for older task/place/goal/log payloads. The default `.routinabackup` package format is the complete backup format for current data.

## Consequences

- New SwiftData user models need backup mapping, import insertion, reset coverage, and regression tests when they are introduced.
- Users can rely on the default local backup before cloud reset to preserve planner, timeline, focus, board, device, media, and core routine data.
- Older JSON backups stay importable, but they are not the authoritative complete export format for current Routina data.
