# 0525 — Gate TestFlight Archives on CloudKit Schema Deployment

Date: 2026-08-09
Status: Accepted

Refines: [0167](0167-merge-icloud-and-backup-settings.md),
[0524](0524-pause-tasks-until-a-date.md)

## Context

CloudKit Development and Production schemas are separate. A build launched
from Xcode can use Development successfully while a TestFlight build uses
Production and cannot read or write a newly added model field until the schema
is deployed in CloudKit Dashboard.

Remembering this release prerequisite is unreliable, and a device-side sync
failure is too late to discover it.

## Decision

The repository records the last explicitly acknowledged Production SwiftData
schema in `Config/CloudKit/production-schema.manifest`. The schema guard derives
a deterministic contract from stored properties of Routina's `@Model` classes,
including each property name and declared storage type.

Both iOS and macOS production targets run the guard during an archive. When the
current contract differs from the manifest, the archive fails before it can be
uploaded to TestFlight. Its build log gives the required sequence: deploy the
Development schema to Production in CloudKit Dashboard, then run the explicit
acknowledgement command and commit the updated manifest.

The acknowledgement command requires the literal
`--yes-i-deployed-to-production` confirmation. It is not run automatically and
the guard never treats a successful development build as evidence of a
Production deployment. The initial manifest is intentionally unacknowledged so
the first archive after this decision establishes a verified baseline.

## Consequences

- A schema change cannot silently pass a normal iOS or macOS TestFlight archive.
- The deployment remains a deliberate owner action in CloudKit Dashboard; the
  repository does not need or store CloudKit Dashboard credentials.
- The committed manifest makes the last acknowledged Production schema visible
  in code review.
- A developer can use `script/cloudkit_schema_guard.sh --check` before
  archiving, but cannot forget the check during the archive itself.
