# 0045: Split Routine Schedule Behavior and Format

- **Status:** Accepted
- **Date:** 2026-05-14

## Context

The task form previously exposed one "Routine style" segmented control with Fixed, Soft, Checklist, and Runout options. That mixed two separate product decisions: whether a routine follows a fixed or soft schedule, and whether the routine is completed as a standard routine, checklist-completion routine, or runout/checklist-driven routine.

This made the UI harder to reason about and prevented combinations like a soft checklist routine.

## Decision

Routine creation and editing treat schedule behavior and routine format as separate axes.

- Schedule behavior is Fixed or Soft.
- Routine format is Standard, Checklist, or Runout.
- The stored `RoutineScheduleMode` keeps representing the combined persisted mode, including soft checklist and soft runout cases.
- Form UI should present the two axes as separate controls instead of one combined routine-style control.

## Consequences

Existing fixed, soft, checklist, and runout routines keep their behavior. New routines can combine soft scheduling with checklist or runout formats. Code that needs to branch on schedule behavior or checklist/runout format should use helper properties on `RoutineScheduleMode` instead of matching only individual enum cases.
