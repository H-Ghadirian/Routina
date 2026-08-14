# 0163 — Do not sync unchanged preferences

Date: 2026-08-14

## Symptom

The production iOS app hitched on Home and around Search transitions even when
the person was not scrolling. Baseline and Search traces showed complete Home
loads recurring every few seconds, with roughly 250–350 milliseconds of
continuous main-thread work per load and a worst Search-close burst near 839
milliseconds.

## Root Cause

Every successful Home task load persisted `TemporaryViewState`, including when
filter validation left it unchanged. The setter rewrote equivalent JSON and
scheduled a SwiftData preference mirror. The mirror copied all durable defaults,
unconditionally changed `RoutinaUserPreferences.updatedAt`, and saved even when
no durable value differed. CloudKit observed that save, the surface coordinator
posted another routine update, and active Home performed another full load.

## Fix

Temporary view state now compares decoded values before writing and no longer
schedules the durable preference mirror. The durable preference bridge changes individual fields
only when their semantic values differ, skips no-op saves and timestamps, and
writes only changed defaults when applying remote preferences. Home persists
temporary state after a task load only when filter validation actually changes
the stored filters.

## Prevention Rule

Never use timestamp advancement or same-value assignment as proof that a
preference changed. Any local-to-synced preference bridge must compare semantic
values in both directions and must not save, notify, or schedule sync for a
no-op. Data refresh handlers may persist view state only when validation changed
that state.

## Regression Safeguard

`RoutinaUserPreferencesStoreTests` verifies that repeated mirror/apply calls do
not save or rewrite unchanged values and that equivalent temporary view state
does not write again. `HomeFeatureTaskLoadHandlerTests` verifies that an ordinary
load skips temporary-state persistence when filter validation reports no
change. [Decision 0569](../decisions/0569-suppress-no-op-preference-sync-refresh-loops.md)
records the durable sync boundary.
