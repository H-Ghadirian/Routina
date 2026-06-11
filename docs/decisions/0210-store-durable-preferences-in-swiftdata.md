# 0210 Store Durable Preferences in SwiftData

- Status: Accepted
- Date: 2026-06-11
- Refines: [0170 Treat Backup and Reset as Complete User Data Operations](0170-treat-backup-reset-as-complete-user-data-operations.md)

## Context

Routina stores some user-facing preferences in `UserDefaults`, including tag metadata, dashboard layout, task-list presentation, blocking settings, notification reminder time, and some Mac-specific app state. A subset of those values was mirrored through iCloud key-value storage, but they were not part of `.routinabackup` packages and were not covered by destructive user-data reset.

Not every default is user data. Temporary view state, pending deep links, diagnostics, migration markers, watch caches, device identifiers, and permission request markers describe the current device or session and should not restore onto every device.

## Decision

Durable, user-owned Routina preferences belong in the primary SwiftData store as `RoutinaUserPreferences`, which syncs through CloudKit, participates in complete backup/import, and is wiped by user-data reset.

The app keeps `UserDefaults` as a compatibility and SwiftUI `@AppStorage` bridge for existing UI. Launch migration copies existing durable defaults into SwiftData, backup mirrors current durable defaults into the SwiftData preference record before export, and CloudKit imports apply the SwiftData preference record back to defaults so existing screens see remote changes.

Ephemeral, diagnostic, cache, migration, permission, and per-device handoff values remain in `UserDefaults`.

## Consequences

- New durable preferences should be added to `RoutinaUserPreferences`, backup mapping, import mapping, reset coverage, and preference bridge code.
- Existing `@AppStorage` call sites can migrate gradually because the bridge keeps durable defaults and SwiftData aligned.
- Device-local defaults must stay out of the SwiftData preference model unless the product explicitly wants them restored and shared across devices.
