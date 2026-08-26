# 0665 — Persist Mac Planner header choices locally

## Status

Accepted

## Date

2026-08-26

## Refines

- [0191: Support one-day Planner view](0191-support-one-day-planner-view.md)
- [0210: Store durable preferences in SwiftData](0210-store-durable-preferences-in-swiftdata.md)
- [0609: Keep Planner range choices actionable in compact headers](0609-keep-planner-range-choices-actionable-in-compact-headers.md)
- [0654: Progressively reveal Mac Planner header choices](0654-progressively-reveal-mac-planner-header-choices.md)

## Context

Mac Planner owned its selected `Calendar` / `Timeline`, `Schedule` / `List`,
and `Day` / `3 Days` / `Week` values only in view and planner-object memory.
Recreating the workspace or relaunching Routina therefore restored hard-coded
defaults even though the controls present the values as the person's current
view choices.

Planner range also has two distinct meanings: the person's preferred range and
the effective range that the current width can render. Persisting the effective
adaptive fallback would incorrectly replace a preferred Week choice merely
because a narrow window temporarily showed Day.

## Decision

- Mac Planner stores its selected Planner view, Calendar task view, and
  preferred range together in one device-local presentation preference.
- Recreating Planner or relaunching Routina restores all three choices. Missing
  or invalid stored fields fall back independently to `Calendar`, `Schedule`,
  and `Week`.
- Only an explicit range selection changes the stored preferred range.
  Width-driven Day or 3 Days fallbacks remain temporary, and the saved
  preference can return when enough width is available.
- The preference is temporary presentation state: it remains in local defaults,
  does not sync or enter backups, and is removed by the existing reset for saved
  filters and temporary selections.
- The one-at-a-time expanded header-control state remains session-only and is
  never persisted.

## Consequences

- Planner returns to the same high-level view, Calendar layout, and preferred
  range after workspace switches and app relaunches.
- A constrained window does not silently rewrite the person's range preference.
- Presentation continuity stays device-local and separate from Planner blocks,
  timeline records, and other user data.
