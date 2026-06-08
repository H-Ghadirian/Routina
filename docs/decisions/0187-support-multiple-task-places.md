# 0187 Support Multiple Task Places

Status: Accepted

Date: 2026-06-08

## Context

Tasks could be linked to one saved place through `placeID`. That kept the editor simple, but it forced users to choose only one relevant location even when a task naturally belongs to several places, such as gym, home, and balcony errands. The add/edit form also exposed this as a single-place picker inside a duplicated `Places`/`Place` section, which made the UI feel heavier than the action needed.

## Decision

Tasks store an ordered list of selected saved places. The existing `placeID` field remains as the first selected place for compatibility with older payloads, older backups, and presentation paths that still need one primary place. Add/edit forms present Places as a compact multi-select menu with a nearby Manage action.

Place filters, place linked counts, backup/import, and CloudKit repair paths should read and preserve the full place list. Older single-place data should migrate through fallback reads so existing tasks still behave as one-place tasks.

## Consequences

Users can link one task to multiple saved places without duplicating the task. Some row and location-availability surfaces may continue to display only the first selected place until they gain a richer multi-place presentation, but filtering and counts should honor all selected places.
