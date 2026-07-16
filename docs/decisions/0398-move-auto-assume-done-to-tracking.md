# 0398 Move Auto-Assume Done to Tracking

Status: Accepted

Date: 2026-07-16

Refines: [0259 Allow Daily Checklist Auto-Assumed Completion](0259-allow-daily-checklist-auto-assumed-completion.md), [0376 Hide Probable Time From Assumed-Done Forms](0376-hide-probable-time-from-assumed-done-forms.md), [0385 Use Gentle Routine Cadence for Tracking](0385-use-gentle-routine-cadence-for-tracking.md), [0397 Make Tracking Cadence Optional](0397-make-tracking-cadence-optional.md)

## Context

Auto-assume done originally belonged to daily routines, where it made a routine default to done until the user confirmed or corrected the day. Tracking now owns the app's lightweight record-and-analysis workflow, including optional routine-like cadence. That makes default-done assumptions fit Tracking better than Task -> Routine: the user is recording what likely happened, not creating a routine obligation that silently resolves itself.

## Decision

`Auto-assume done` moves from Task -> Routine to Tracking.

Eligible Tracking entries are daily standard Tracking entries with cadence enabled, no sequential steps, and no optional checklist items, plus daily checklist-completion Tracking entries with cadence enabled and checklist items. Tracking entries with `No repeat`, item-runout Tracking, Tracking with steps, standard Tracking with optional checklist items, non-daily Tracking, todos, and routines do not qualify.

Task creation and Task Detail editing hide the control for routines. Save paths clear routine-owned auto-assume values when a routine is saved, while legacy stored values remain readable for backup/import compatibility and no longer make routines eligible.

Synthetic assumed-done activity keeps the existing review model: it does not create completion logs, does not create editable Schedule placements, and can still be confirmed or marked missed from Home, Planner day agendas, and Calendar List review.

## Consequences

- Auto-assumed days now describe Tracking expectations instead of routine completion pressure.
- Routines must be completed, missed, canceled, or fulfilled explicitly.
- Existing routine data that carries old auto-assume fields remains compatible but inert until edited/saved.
