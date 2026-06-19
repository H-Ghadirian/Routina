# 0257 Hide Task Sharing Behind Beta Toggle

- Status: Accepted
- Date: 2026-06-19
- Refines: [0210 Store Durable Preferences in SwiftData](0210-store-durable-preferences-in-swiftdata.md)

## Context

CloudKit task sharing is implemented from task detail toolbars, but sharing is still a sensitive and less commonly used collaboration surface. Routina already uses Support & About -> Beta Experiments to keep optional or still-stabilizing features available without exposing them in the default task workflow.

## Decision

Task sharing is hidden by default. Support & About -> Beta Experiments exposes an `Enable task sharing` toggle backed by `appSettingTaskSharingEnabled`.

When the toggle is off, task detail surfaces hide the CloudKit task-sharing control. Stable deep-link sharing remains available as the separate `Link` menu because it is a local link utility rather than the CloudKit task-sharing workflow.

The preference is user-owned and durable, so it is mirrored into `RoutinaUserPreferences` for backup, import, reset, and sync behavior.

## Consequences

- Fresh installs do not show task sharing in task details.
- Users who want CloudKit task sharing can opt in from Beta Experiments.
- Backup/import and settings reset preserve the same default/off contract as other durable app settings.
