# 0010: Store Recurrence Rules in SwiftData Columns

## Status

Accepted

## Date

2026-05-09

## Context

Routine recurrence rules used to be stored as a JSON string on `RoutineTask`. That made additive changes easy, but it hid user scheduling data inside an opaque blob and made the persistence model harder to inspect, migrate, and sync as first-class task data.

## Decision

Routina stores recurrence rule metadata in typed SwiftData fields on `RoutineTask`: recurrence kind, timing mode details, weekday or day-of-month values, and time-range start/end components.

The legacy JSON field remains in the model only as a migration source. New writes populate the typed SwiftData columns and clear the JSON string. On startup, Routina backfills tasks that still have legacy JSON recurrence data into the SwiftData columns.

## Consequences

- Recurrence data is inspectable and synced as normal SwiftData task fields.
- Existing stores can open with a lightweight additive schema change before the app backfills the typed columns.
- The legacy JSON field should not be used for new recurrence writes.
- Removing the legacy field entirely should wait until a later schema migration can safely prove all active stores have been backfilled.
