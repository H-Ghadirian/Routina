# Settings Current Behavior

This page summarizes active Settings, durable preference, backup, reset, App Lock, and build-entry behavior.

## Key Decisions

- [0165](../decisions/0165-suggest-backup-before-cloud-data-reset.md)
- [0166](../decisions/0166-use-app-lock-for-cloud-data-reset.md)
- [0167](../decisions/0167-merge-icloud-and-backup-settings.md)
- [0168](../decisions/0168-require-recent-backup-for-cloud-data-reset.md)
- [0170](../decisions/0170-treat-backup-reset-as-complete-user-data-operations.md)
- [0210](../decisions/0210-store-durable-preferences-in-swiftdata.md)
- [0235](../decisions/0235-require-authentication-to-disable-app-lock.md)
- [0237](../decisions/0237-hide-settings-devices-behind-beta-toggle.md)
- [0238](../decisions/0238-use-project-local-mac-dev-run-entrypoint.md)
- [0241](../decisions/0241-gate-settings-reset-with-app-lock.md)
- [0248](../decisions/0248-add-explicit-mac-prod-run-entrypoint.md)
- [0257](../decisions/0257-hide-task-sharing-behind-beta-toggle.md)
- [0258](../decisions/0258-hide-linked-task-visualizer-behind-beta-toggle.md)
- [0275](../decisions/0275-hide-places-behind-beta-toggle.md)
- [0277](../decisions/0277-hide-notes-and-away-behind-beta-toggles.md)
- [0279](../decisions/0279-hide-sleep-stats-and-blocking-with-away-toggle.md)
- [0284](../decisions/0284-hide-filter-query-sections-behind-beta-toggle.md)

## Current Contract

- User-owned preferences that should back up, restore, reset, and sync belong in SwiftData.
- Temporary, diagnostic, cache, migration, permission, and per-device handoff values can remain in `UserDefaults`.
- iCloud sync, reset, backup import, and backup export live in one iCloud & Backup settings section.
- Default `.routinabackup` export/import and destructive reset are complete user-data operations over the SwiftData user model set.
- Legacy `.json` backup remains compatibility-only for older task, place, goal, and log payloads.
- Data-wide reset actions show backup/export first when possible.
- Destructive data reset requires a successful local backup export from the last 24 hours and fresh App Lock authentication.
- Settings reset requires App Lock to already be enabled and a fresh successful device-owner authentication. User content remains untouched.
- Turning App Lock off requires fresh device-owner authentication.
- Settings hides Devices by default behind the beta toggle.
- Settings hides Places by default behind Support & About -> Beta Experiments -> `Show Places`.
- Settings hides Notes and Away by default behind Support & About -> Beta Experiments; while Away is off, Blocking exposes only Focus mode controls and Stats hides Sleep-specific surfaces.
- Task sharing is off by default and hidden in task details until enabled from Support & About -> Beta Experiments.
- The linked-task Visualize button is off by default and hidden in task details until enabled from Support & About -> Beta Experiments.
- Home and Stats Query sections are hidden in filter panels until enabled from Support & About -> Beta Experiments.
- macOS development runs use `script/build_and_run.sh` by default. Production launches use the explicit `--prod` path.
