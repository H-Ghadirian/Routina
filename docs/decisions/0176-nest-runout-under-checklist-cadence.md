# 0176: Nest Runout Under Checklist Cadence

## Status

Accepted

## Date

2026-06-07

Refines [0045](0045-split-routine-schedule-behavior-and-format.md) and [0175](0175-use-routine-finish-mode-for-checklist-creation.md) for routine creation and editing.

## Context

After removing the optional More Details checklist entry path for empty standard routines, routine forms still presented `Standard`, `Checklist`, and `Runout` side by side under `How it finishes`.

That kept the data model visible too literally. Runout is not a third way to finish a routine; it is a checklist timing strategy where checklist items carry their own due cadence and the earliest due item drives the routine.

## Decision

Routine forms present the Completion control as `Standard` or `Checklist` only. Choosing `Checklist` reveals a checklist cadence/timing control in the repeat cadence area with:

- `Together`: checklist items follow the routine cadence and the routine is done when every item is completed.
- `Runout`: checklist items have their own timing and the earliest due item drives the routine.

The stored `RoutineScheduleMode` and `RoutineFormat` values still represent standard, checklist, and runout variants so existing data, sync, parser output, and completion behavior remain compatible.

## Consequences

- Routine creation has one top-level checklist entry path.
- Runout is grouped with the checklist controls it depends on, reducing confusion between finish behavior and item timing.
- UI code should use a Standard/Checklist finish binding for routine form pickers and a separate checklist timing binding when Checklist is selected.
- Persistence and domain logic may continue to branch on checklist versus runout schedule modes where the behavior genuinely differs.
