# Backup Audit

Use the project-local audit before loading a production backup into the development app:

```sh
script/audit_backup.sh /path/to/Routina-Backup.routinabackup
```

The command performs these checks without opening or changing Routina's production, development, or CloudKit stores:

1. Decode `manifest.json` and require a schema supported by the current checkout.
2. For a current package, require `verification.json` and verify its raw manifest digest, source semantic fingerprint, record inventory, and every attachment's byte count and SHA-256 digest.
3. Reject unsafe or duplicate attachment names and IDs, dangling references, missing files, and symbolic-link or non-file attachments.
4. Restore through Routina's real import mapping into an in-memory local-only store.
5. Re-export without copying device defaults into the audited data.
6. Restore that export into a second isolated store and compare canonical semantic snapshots.

For a current-schema package, the original snapshot must match the first restore and the second round trip. For an older supported package, import may legitimately add current defaults, so the command verifies that the migrated result is stable across the second round trip and labels the result accordingly.

A successful result includes record counts, attachment size, a semantic fingerprint, and whether a portable source receipt was verified. The receipt was created by comparing the exported package with the source device, so it remains useful when the destination device is empty. It confirms package integrity and restore stability for the current code. It does not compare the package with a currently open app store, verify CloudKit upload, schedule notifications, inspect every screen's presentation, or prove available disk space during a real import.

Inside Routina, `Verify Backup` performs the receipt and isolated checks and also compares the selected package with the current local app data without changing it. Restore performs the receipt and isolated checks before creating a verified recovery point and committing an all-or-nothing local replacement.

Decisions: [0693](decisions/0693-audit-backups-through-isolated-semantic-round-trips.md), [0694](decisions/0694-verify-portable-backups-and-preserve-restore-recovery.md).
