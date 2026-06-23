# 0272: Present Sleep as Away Start Preset

## Status

Accepted

## Date

2026-06-23

## Refines

- [0012: Model Sleep as an App-Level Session Mode](0012-model-sleep-as-app-level-session-mode.md)
- [0125: Support Away Sessions](0125-support-away-sessions.md)
- [0220: Nest Sleep and Gate Mac Event and Emotion Actions](0220-nest-sleep-and-gate-mac-event-emotion-actions.md)

## Context

Decision 0220 moved Sleep out of the default Mac Add menu and into the inline Away start surface as a secondary `Start Sleep` action. That kept Sleep grouped with related protected away-from-screen flows, but it left the default Away start panel with two competing start controls: one primary Away action and one separate Sleep action.

The Away start surface already asks users to choose a protected-mode preset before starting. Sleep fits that scanning model better as another protected-mode choice than as a separate button beneath the summary.

## Decision

The Mac inline Away start surface presents Sleep as a selectable preset alongside Away presets. Selecting the Sleep preset changes the hero, summary, tint, and primary action to Sleep, and hides Away-only timer and linked-task controls.

Starting the Sleep preset still uses the existing Mac Sleep starter, including the active-focus warning behavior, and creates or reuses a `SleepSession`. It does not create an `AwaySession`, does not store Sleep in `AwaySessionPreset`, and does not merge Sleep planner, stats, blocking, or timeline semantics into Away history.

Away sessions continue to use only `AwaySessionPreset` values for persisted Away records, editing, backup/import, and finished Away logs.

## Consequences

- The Away start panel has one primary start action, driven by the selected preset.
- Sleep remains visually grouped with Away without being modeled as Away data.
- Away timer and linked-task controls stay hidden for Sleep because the Sleep starter ignores those fields.
