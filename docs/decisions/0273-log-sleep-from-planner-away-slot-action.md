# 0273: Log Sleep From Planner Away Slot Action

## Status

Accepted

## Date

2026-06-23

## Refines

- [0012: Model Sleep as an App-Level Session Mode](0012-model-sleep-as-app-level-session-mode.md)
- [0125: Support Away Sessions](0125-support-away-sessions.md)
- [0269: Support Planner Slot Actions](0269-support-planner-slot-actions.md)
- [0272: Present Sleep as Away Start Preset](0272-present-sleep-as-away-start-preset.md)

## Context

Planner empty-slot actions originally offered `Task` and `Away`, and the Away branch logged completed `AwaySession` records using `AwaySessionPreset` values. Separately, the Mac Away start surface presents Sleep alongside Away presets because the user-facing intent is leaving the screen, even though Sleep is backed by a distinct `SleepSession` model.

That split made the Planner inconsistent: a user who clicked empty time to record screen-away time could choose meal, outside, wind-down, or generic Away, but not Sleep. From the user's perspective, Sleep is a normal reason to be away from the phone or laptop.

## Decision

The Planner empty-slot action popover keeps `Away` as the user-facing umbrella and presents Sleep alongside the Away presets. Selecting an Away preset logs a completed `AwaySession`. Selecting Sleep logs a completed `SleepSession`.

Sleep remains a separate app-level protected session model. It is not added to `AwaySessionPreset`, not stored as an Away record, and does not merge Sleep stats, planner, blocking, timeline, backup/import, or deep-link semantics into Away history.

The popover adapts controls to the selected option: Away presets can keep Away-only title and linked-task fields, while Sleep hides those fields and uses Sleep wording and duration defaults.

## Consequences

- Planner slot logging matches the Mac Away starter's user-facing promise that Away includes Sleep as a reason to leave the screen.
- Future slot actions should keep user-facing grouped intents separate from persistence enums when the models have distinct semantics.
- Finished Sleep logs must use the SleepSession validation path and reject overlaps with Away, Focus, or other Sleep intervals.
