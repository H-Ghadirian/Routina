# Backup Audit

Use the project-local audit before loading a production backup into the development app:

```sh
script/audit_backup.sh /path/to/Routina-Backup.routinabackup
```

The command performs these checks without opening or changing Routina's production, development, or CloudKit stores:

1. Decode `manifest.json` and require a schema supported by the current checkout.
2. Reject unsafe or duplicate attachment names and IDs, dangling references, missing files, and symbolic-link or non-file attachments.
3. Hash every attachment with SHA-256.
4. Restore through Routina's real import mapping into an in-memory local-only store.
5. Re-export without copying device defaults into the audited data.
6. Restore that export into a second isolated store and compare canonical semantic snapshots.

For a current-schema package, the original snapshot must match the first restore and the second round trip. For an older supported package, import may legitimately add current defaults, so the command verifies that the migrated result is stable across the second round trip and labels the result accordingly.

A successful result includes record counts, attachment size, and a semantic fingerprint. It confirms package integrity and restore stability for the current code. It does not verify CloudKit upload, notification scheduling, every screen's presentation, available disk space during a real import, or make the live replacement flow transactional. Save a separate development backup before importing.

Decision: [0693](decisions/0693-audit-backups-through-isolated-semantic-round-trips.md).
