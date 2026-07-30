# 0465: Prepare the Mac Development App for Screenshots

## Status

Accepted

## Date

2026-07-29

## Refines

- [0238: Use Project-Local Mac Dev Run Entrypoint](0238-use-project-local-mac-dev-run-entrypoint.md)
- [0341: Consolidate Mac Home Toolbar Row](0341-consolidate-mac-home-toolbar-row.md)
- [0361: Make Mac Done Toolbar Count Optional](0361-make-mac-done-toolbar-count-optional.md)

## Context

The isolated Mac development app is the safest place to prepare App Store and
documentation screenshots, but a new development store does not contain enough
representative activity to make Home, Planner, Timeline, and Stats meaningful.
The orange `Dev Version` toolbar badge also identifies the build in captures even
when every other surface is ready.

Screenshot preparation must not weaken the visual distinction by default, expose
development tools in production, replace existing development data, or duplicate
sample records every time the preparation action runs.

## Decision

The Mac development app exposes screenshot preparation under Settings ->
Appearance:

- `Show development badge` controls the orange Home toolbar badge and defaults
  on. Turning it off changes presentation only; the app continues using its
  isolated development identity, store, iCloud container, and deep-link scheme.
- `Generate Screenshot Data` adds a curated dataset with routines, todos,
  completion and exception history, planner blocks, completed focus sessions,
  goals, notes, events, emotion logs, sleep sessions, and Away sessions.
- Generated records use a reserved deterministic identifier namespace. Repeating
  the action inserts only missing records and preserves all unrelated data.
- The generator is available only to the development app. Production hides the
  controls and rejects the one-shot launch environment trigger.

For automated preparation of the normal development store,
`ROUTINA_SCREENSHOT_DATA_SEED=1` requests the same generator at launch and
`ROUTINA_SCREENSHOT_DATA_SEED_EXIT=1` exits after the attempt. The in-app action
posts Routina's ordinary data-refresh notification after inserting records.

## Consequences

- The development app can present realistic, date-relative content across its
  main screenshot surfaces without borrowing production data.
- The build-identifying badge remains safe by default but can be hidden
  temporarily for clean captures.
- Existing development work is not erased, and repeated preparation does not
  accumulate duplicate sample rows.
- Screenshot-only controls and launch flags cannot seed the production app.
