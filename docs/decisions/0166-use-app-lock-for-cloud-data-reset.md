# 0166 Use App Lock for Cloud Data Reset

- Status: Accepted
- Date: 2026-06-06
- Supersedes: [0164 Require a Password for Cloud Data Reset](superseded/0164-require-password-for-cloud-data-reset.md)
- Refines: [0165 Suggest Backup Before Cloud Data Reset](0165-suggest-backup-before-cloud-data-reset.md)

## Context

Routina already has App Lock, backed by device owner authentication such as Face ID, Touch ID, device passcode, or Mac password. A separate one-time deletion password creates a second confirmation concept that is weaker and less consistent than the app's existing lock model.

## Decision

Cloud data reset uses App Lock as its authentication gate. If App Lock is off, the reset confirmation asks the user to turn it on first. Enabling App Lock uses device authentication and persists the App Lock setting. Once App Lock is on, deleting iCloud data requires a fresh device-authentication pass before the reducer starts the destructive reset.

## Consequences

- Cloud reset uses the same authentication model as app entry protection.
- The custom one-time deletion password flow is removed.
- The reset flow remains blocked on devices where App Lock cannot be enabled because device authentication is unavailable.
