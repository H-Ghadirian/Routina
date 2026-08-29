# 0693 Audit Backups Through Isolated Semantic Round Trips

- Status: Accepted
- Date: 2026-08-29
- Refines: [0170 Treat Backup and Reset as Complete User Data Operations](0170-treat-backup-reset-as-complete-user-data-operations.md)

## Context

The automated backup tests cover representative records and relationships, but they do not prove that one specific production export is structurally complete or that the current development build will restore its exact contents. Testing that question by importing directly into the development store is unnecessarily risky because import replaces that store and currently commits deletion before every restored record is guaranteed to save.

A useful audit must exercise the real backup decoder, import mappings, SwiftData models, attachment handling, and export mappings without opening either app store or using CloudKit. Raw package equality is insufficient because export order and generated media-attachment identifiers are intentionally unstable, and older supported schemas legitimately gain current defaults during import.

## Decision

Provide `script/audit_backup.sh <backup.routinabackup>` as the project-local backup audit entrypoint.

The audit validates the manifest, supported schema, attachment names, uniqueness, references, regular-file presence, and attachment bytes. It restores through the production import mapping into a new in-memory, local-only `ModelContainer`, exports that result without mirroring device defaults, restores the export into a second isolated container, and compares canonical semantic snapshots that preserve record and relationship ordering while normalizing only generated media identifiers and export time.

For a backup already using the current schema, the source snapshot must equal the first isolated restore and that result must remain equal after a second round trip. For an older supported schema, the audit reports migration mode and requires the first migrated result to remain stable after the second round trip; it does not misrepresent schema-default expansion as raw source equality.

Audit restore must not clear live CloudKit pull tokens, apply restored preferences to device defaults, initialize the production or development persistent store, or contact CloudKit. Successful output reports category counts, attachment size, and a SHA-256 semantic fingerprint without printing personal record contents.

## Consequences

- A real production package can be checked before replacing development data.
- The audit exercises the same persistence mappings as the app while keeping application and cloud stores outside its scope.
- A passing audit establishes structural integrity and deterministic restore semantics for the tested build; it does not prove subsequent CloudKit upload, notification scheduling, UI presentation, free disk capacity during a real import, or the absence of every possible defect.
- Development data still needs its own backup before a real import until the live replacement flow becomes transactional.
