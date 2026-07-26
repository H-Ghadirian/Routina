# 0428 Compose Tracking Behaviors on Gentle Routines

Status: Accepted

Date: 2026-07-26

Refines: [0382 Split Record Task Form Controls](0382-split-record-task-form-controls.md), [0396 Allow Quiet Tracking Cadence](0396-allow-quiet-tracking-cadence.md), [0398 Move Auto-Assume Done to Tracking](0398-move-auto-assume-done-to-tracking.md), [0413 Nest Tracking Under Repeating Task Creation](0413-nest-tracking-under-repeating-task-creation.md), [0414 Align Task Kind Controls Between Create and Edit](0414-align-task-kind-controls-between-create-and-edit.md), [0421 Support Cadence-Free Repeating Routines](0421-support-cadence-free-repeating-routines.md)

## Context

`Track this routine` made Tracking look like a required purpose instead of a
combination of scheduling behaviors. Users had to understand a separate task
type to get Gentle cadence, optional nudges, or auto-assumed daily completion,
even though those choices can describe an ordinary repeating routine directly.

The internal `record` type already has persisted data, sync and backup payloads,
dedicated list placement, Stats filters, and actual-time metadata. Removing or
rewriting that stored type in the same change would risk existing data without
being necessary to simplify new task behavior.

## Decision

Full Add Task and Edit Task forms offer only `One-time` and `Repeating` as the
task-kind choice. They do not expose `Track this routine`. A newly selected
Repeating task is a routine.

Repeating behavior is composed from independent controls:

- `Due` keeps due and overdue pressure.
- `Gentle` removes overdue pressure and exposes a `Nudges` preference.
- Turning Nudges off preserves cadence and history but suppresses Ready and
  Gentle-nudge threshold badges.
- Eligible daily Gentle Standard and Checklist-completion routines may enable
  `Auto-assume done`.
- Due routines, cadence-free routines, non-daily routines, item-runout
  routines, Standard routines with steps or optional checklist items, and
  ineligible checklist structures cannot enable auto-assume.
- `Repeat type: None` has no cadence, so Due style, Nudges, and Auto-assume are
  inactive.

The persisted `trackingCadenceEnabled` and `trackingNudgesEnabled` names remain
for storage compatibility, but their behavior now applies to routines as well
as legacy Tracking records.

Existing internal `record` tasks remain readable, editable, shareable,
importable, and visible in their existing Tracking surfaces. No automatic
migration changes their type or history. The full task form no longer creates
new records; dedicated Tracking sections and Tracking-only Stats therefore
remain compatibility surfaces for existing data.

## Consequences

- Users can construct quiet tracking behavior with a Gentle routine, Nudges
  off, and optional daily Auto-assume without choosing a separate purpose.
- Due/Gentle, cadence, nudges, completion format, and eligible auto-assumption
  are modular instead of being coupled to Tracking storage identity.
- Existing Tracking data keeps its specialized metadata and presentation until
  a separately designed migration removes the legacy type.
- New routines do not acquire Tracking-only actual-duration or dedicated
  Tracking-section identity merely because they use Gentle behavior.
