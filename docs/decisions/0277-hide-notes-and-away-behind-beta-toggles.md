# 0277 Hide Notes and Away Behind Beta Toggles

- Status: Accepted
- Date: 2026-06-25
- Refines: [0060 Support Standalone Notes](0060-support-standalone-notes.md), [0125 Support Away Sessions](0125-support-away-sessions.md), [0206 Capture Status From Mac Sidebar](0206-capture-status-from-mac-sidebar.md), [0226 Hide Mac Status Note Section Behind Beta Toggle](0226-hide-mac-status-note-section-behind-beta-toggle.md), [0239 Link and Edit Away Sessions](0239-link-and-edit-away-sessions.md), and [0275 Hide Places Behind Beta Toggle](0275-hide-places-behind-beta-toggle.md)

## Context

Notes and Away had become first-class app surfaces across creation menus, Home, Timeline, Planner, Stats, Settings, task detail metadata, context links, blocking, shortcuts, and backup/import. They remain implemented and data-compatible, but they are experimental enough that fresh installs should not expose them unless the user opts in.

## Decision

Notes and Away are hidden by default behind Support & About -> Beta Experiments -> `Show Notes` and `Show Away`.

When Notes is off, app-facing surfaces must not present standalone note creation, note detail routing, note timeline filters, note stats, note-derived tag suggestions/counts, note links, task note/voice-note fields, goal/event note fields, status-note composer controls, or note-specific shortcut/help rows. Existing note models, backup/import support, reset, sync repair, and compatibility code remain in place so existing note data is preserved and can reappear when Notes is enabled.

When Away is off, app-facing surfaces must not present Away creation, active Away overlays, Away planner blocks/actions, Away timeline filters, Away stats, Away blocking-mode controls, Away shortcut/help rows, or hidden Away interference with Focus/Sleep flows. Existing `AwaySession` data and backup/import support remain in place for compatibility and reappear when Away is enabled.

Both preferences are durable and user-owned, stored as `appSettingNotesEnabled` and `appSettingAwayEnabled`, mirrored into `RoutinaUserPreferences`, and included in backup/import behavior.

## Consequences

- Fresh installs do not show Notes or Away in New/Add menus, Timeline quick filters, Stats summaries, Planner actions, Settings secondary rows, Mac status composer controls, or shortcut/help surfaces.
- Existing Notes and Away data is preserved while hidden rather than deleted or stripped from backups.
- Tests and future feature work must opt into Notes or Away explicitly when asserting those feature-specific behaviors.
