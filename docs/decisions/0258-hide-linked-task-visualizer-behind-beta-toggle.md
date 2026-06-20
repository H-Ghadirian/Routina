# 0258 Hide Linked Task Visualizer Behind Beta Toggle

- Status: Accepted
- Date: 2026-06-20
- Refines: [0210 Store Durable Preferences in SwiftData](0210-store-durable-preferences-in-swiftdata.md)

## Context

Task details can visualize linked-task relationships as a graph, but the Visualize button adds another control to the default linked-task section. Routina already uses Support & About -> Beta Experiments to keep optional task-detail affordances available without making the default workflow denser.

## Decision

Task detail hides the linked-task Visualize button by default. Support & About -> Beta Experiments exposes a `Show linked task visualizer` toggle backed by `appSettingTaskRelationshipVisualizerEnabled`.

The preference is user-owned and durable, so it is mirrored into `RoutinaUserPreferences` for backup, import, reset, and sync behavior.

## Consequences

- Fresh installs do not show the linked-task Visualize button in task details.
- Users who want the linked-task relationship graph can opt in from Beta Experiments.
- Backup/import and settings reset preserve the same default/off contract as other durable app settings.
