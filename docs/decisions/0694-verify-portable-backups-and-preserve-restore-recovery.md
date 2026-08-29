# 0694 Verify Portable Backups and Preserve Restore Recovery

- Status: Accepted
- Date: 2026-08-29
- Refines: [0170 Treat Backup and Reset as Complete User Data Operations](0170-treat-backup-reset-as-complete-user-data-operations.md), [0693 Audit Backups Through Isolated Semantic Round Trips](0693-audit-backups-through-isolated-semantic-round-trips.md)

## Context

An isolated restore audit can prove that a package is structurally readable, but a
package copied to a new device also needs portable evidence that it still contains
the exact semantic snapshot Routina compared with the source device. Comparing it
with the new device is not that proof: the new device may be empty, and its current
data may intentionally differ.

Restore also used to save deletion of the destination before every imported record
was inserted and saved. A later attachment or persistence failure could therefore
leave the only live store empty or partial. Even a successful restore can reveal a
semantic omission much later, after the person has continued working and no longer
has the earlier device.

## Decision

Every new `.routinabackup` user export uses backup schema 41 and is successful only
after Routina restores it in isolated local-only stores, compares its canonical
semantic snapshot with the source `ModelContext`, hashes the raw manifest and every
attachment, and writes those results to `verification.json`. The manifest declares
the receipt version, so removing the receipt from a current package is an error.
Older supported packages remain importable after isolated restore verification and
are described honestly as lacking source verification.

On any device, restore first validates the receipt, file hashes, package structure,
and isolated semantic round trip. This compares transferred bytes and restored
meaning with the receipt made from the source data; it does not require the source
data to exist on the destination. The separate `Verify Backup` action additionally
compares a selected package with the currently open local store and reports whether
they match without changing either one.

Before replacing live data, Routina creates and verifies a recovery package of the
current destination store. It retains the ten newest recovery points and exposes
them in iCloud & Backup. These points live inside Routina's Application Support
directory, so they protect delayed discovery after an in-app restore but do not
survive app deletion; device transfer still requires an externally saved verified
export.

Live replacement deletes and inserts all user records in one unsaved SwiftData
transaction and performs one final save. A failure rolls the context back before
CloudKit pull tokens or device defaults are changed. Notification reconciliation
happens after the committed restore; failure there is reported as a non-destructive
warning rather than misreporting the data restore as failed.

The receipt is an integrity and source-correspondence check, not a cryptographic
signature against an attacker. Neither it nor `Verify Backup` inventories the
server-side private CloudKit database. Cloud comparison remains a separate future
diagnostic because Routina currently has no authoritative CloudKit inventory API.

## Consequences

- A copied backup can be checked on an empty new device against portable source
  evidence and through the real restore mappings.
- A changed manifest, attachment, receipt, or restored semantic snapshot blocks
  restore before live data changes.
- A destination persistence failure cannot commit an empty or partial replacement.
- A person can restore one of ten recent pre-restore states when a problem is found
  later, while understanding that those app-internal points are not uninstall-safe.
- Exact comparison with the current app data is available on demand and remains
  distinct from both portable verification and CloudKit synchronization status.
