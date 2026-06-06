# 0168 Require Recent Backup for Cloud Data Reset

- Status: Accepted
- Date: 2026-06-06
- Refines: [0165 Suggest Backup Before Cloud Data Reset](0165-suggest-backup-before-cloud-data-reset.md), [0166 Use App Lock for Cloud Data Reset](0166-use-app-lock-for-cloud-data-reset.md), [0167 Merge iCloud and Backup Settings](0167-merge-icloud-and-backup-settings.md)

## Context

Cloud data reset is destructive even with App Lock confirmation. Showing backup first helps, but users can still skip the backup action unless the reset flow treats a recent backup as a prerequisite.

## Decision

Cloud data reset requires a successful Routina backup export from the last 24 hours before the destructive reset can start. Routina records the timestamp of successful backup exports locally, hydrates it into Settings, shows freshness in iCloud & Backup, disables the reset confirmation Delete action when the backup is stale or missing, and refuses to start App Lock authentication or reset execution without a recent backup.

## Consequences

- Users must create a recovery point shortly before deleting iCloud data.
- The backup freshness requirement is local to the device that will perform the reset.
- Importing a backup does not count as a recent backup; only successful export creates the reset prerequisite.
