# Decision 0618: Keep task destinations independent from saved Places

Status: Accepted

Date: 2026-08-20

## Context

People need to remember where a one-off task happens and reach that location quickly. Routina already has a Places experiment, but saved Places are named, reusable, geofenced entities used for availability and check-in. Reusing that model for every task address would make a one-off destination unexpectedly participate in Places availability, location permissions, and beta-only behavior.

## Decision

Tasks may store an optional destination address and optional latitude/longitude independently from `RoutinePlace` links. Add Task and Edit Task expose an Address section with an explicit map lookup. Task Details show the saved address and a MapKit preview when coordinates exist. On iPhone, Task Details offer Apple Maps and Google Maps actions using provider URLs; the URLs may fall back to the provider's web experience when its app is unavailable.

Destination data is copied with tasks and included in CloudKit pull, shared-task payloads, and routine backup/import. A destination never creates or changes a saved Place, does not depend on the Places beta toggle, and does not enable geofenced check-in. If an address has no coordinates, the address remains visible while the map and navigation actions remain unavailable.

## Consequences

- A task can carry a useful one-off location without entering the Places experiment.
- Address lookup is explicit, so typing an address does not silently alter its coordinates.
- Existing saved-place semantics, availability filtering, check-in, and Places visibility remain unchanged.
- Coordinates are optional and can become stale if a person edits an address without running lookup again; the form clears the pin when the resolved address is changed.
