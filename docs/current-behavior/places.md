# Places Current Behavior

This page summarizes active Places, saved-place, check-in, and map behavior.

## Key Decisions

- [0014](../decisions/0014-model-place-check-ins-as-place-sessions.md)
- [0015](../decisions/0015-support-map-based-place-check-ins.md)
- [0016](../decisions/0016-show-place-check-ins-as-day-timeline.md)
- [0021](../decisions/0021-keep-mac-places-in-home-split-shell.md)
- [0025](../decisions/0025-show-place-check-in-history-markers-on-map.md)
- [0027](../decisions/0027-show-places-day-as-grouped-history.md)
- [0028](../decisions/0028-default-places-to-check-ins-history.md)
- [0029](../decisions/0029-create-saved-places-from-map.md)
- [0031](../decisions/0031-auto-check-in-at-saved-places.md)
- [0040](../decisions/0040-make-automatic-place-check-in-configurable.md)
- [0187](../decisions/0187-support-multiple-task-places.md)
- [0190](../decisions/0190-support-place-kind-availability.md)
- [0225](../decisions/0225-remove-place-management-from-settings.md)
- [0230](../decisions/0230-unify-map-pin-place-and-check-in-actions.md)
- [0231](../decisions/0231-open-mac-place-toolbar-directly.md)
- [0232](../decisions/0232-allow-known-pin-check-in.md)
- [0233](../decisions/0233-allow-selected-saved-place-check-in.md)
- [0234](../decisions/0234-hide-current-place-map-check-in.md)
- [0275](../decisions/0275-hide-places-behind-beta-toggle.md)

## Current Contract

- Places is hidden by default behind Support & About -> Beta Experiments -> `Show Places`.
- When Places is off, visible app surfaces do not show place navigation, Check In entry points, task place sections, place filters, place stats, place timeline filters, Quick Add place help/parsing, Watch place sync, or Settings Places controls.
- Place check-ins are duration-based `PlaceCheckInSession` records and timeline evidence.
- Place check-ins are distinct from planner blocks, sleep, and focus sessions.
- Tasks can link to multiple saved places. The first selected place remains the compatibility primary.
- Saved places can carry optional kinds so a task linked to one saved place can also be available at other saved places of the same kind.
- Places supports saved-place creation, map-based check-in, grouped history markers, raw current-location sessions, configurable automatic saved-place check-ins, and check-in correction.
- The map shows one location action panel.
- Unsaved map locations offer Add Place and Check In.
- Pinned locations and selected saved-place markers inside saved places offer Check In but not Add Place when they are away from the current resolved place.
- If a selected or pinned saved place matches the current resolved place, Check In is hidden.
- Known current-location saved-place panels may remain informational only.
- Settings -> Places is focused on check-in behavior and diagnostics. Place creation and saved-place management happen on dedicated Places surfaces.
