# 0165 Suggest Backup Before Cloud Data Reset

- Status: Accepted
- Date: 2026-06-06
- Refines: [0164 Require a Password for Cloud Data Reset](0164-require-password-for-cloud-data-reset.md)

## Context

The iCloud reset flow is destructive even with a typed password gate. A user who reaches this screen should be pushed toward creating a restorable backup before taking the final delete action.

## Decision

The cloud data reset confirmation presents backup as the first step. The confirmation sheet recommends saving a Routina backup, exposes a direct `Save Backup First` export action, and shows backup progress or the last backup result before the deletion password section.

## Consequences

- Users see a recovery-oriented action before the destructive confirmation controls.
- The reset password remains the final gate, but backup is the first visible path.
- Future data-wide destructive flows should place backup or export options before irreversible actions when a recovery artifact can be created.
