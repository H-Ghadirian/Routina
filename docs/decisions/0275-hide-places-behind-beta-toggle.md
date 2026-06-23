# 0275 Hide Places Behind Beta Toggle

- Status: Accepted
- Date: 2026-06-23
- Refines: [0014 Model Place Check-Ins as Place Sessions](0014-model-place-check-ins-as-place-sessions.md), [0015 Support Map-Based Place Check-Ins](0015-support-map-based-place-check-ins.md), [0021 Keep Mac Places in the Home Split Shell](0021-keep-mac-places-in-home-split-shell.md), [0187 Support Multiple Task Places](0187-support-multiple-task-places.md), [0190 Support Place Kind Availability](0190-support-place-kind-availability.md), [0225 Remove Place Management From Settings](0225-remove-place-management-from-settings.md), and [0231 Open Mac Place Toolbar Directly](0231-open-mac-place-toolbar-directly.md)

## Context

Places, saved-place availability, and place check-ins are implemented across Home, task forms, task details, filters, stats, timeline, Watch sync, and Settings. That made Places behave like a first-class default app surface, but the feature is still experimental enough that users should not see place-related UI unless they opt in.

## Decision

Places is hidden by default behind Support & About -> Beta Experiments -> `Show Places`.

When the toggle is off, visible app surfaces must not present place-related navigation, creation, filtering, task metadata, timeline filters, stats, achievements, Quick Add help, quick-add place parsing, Watch place sync, or Settings Places controls. Existing place models, import/export support, and compatibility code remain in place so existing data is preserved and the feature can reappear when the toggle is enabled.

The preference is durable and user-owned, stored as `appSettingPlacesEnabled`, mirrored into `RoutinaUserPreferences`, and included in backup/import behavior.

## Consequences

- Fresh installs do not show Settings -> Places, Places in Mac Home, Check In entry points, task place sections, place filters, place stats, or place timeline filters.
- Users can opt into Places from Beta Experiments without losing existing saved places or check-in history.
- Places implementation and data migration remain active for compatibility, but app-facing behavior must check the beta preference before exposing place affordances.
