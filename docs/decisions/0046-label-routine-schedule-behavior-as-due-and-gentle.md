# 0046: Label Routine Schedule Behavior as Due and Gentle

- **Status:** Accepted
- **Date:** 2026-05-14
- **Refined by:** [0180](0180-clarify-schedule-behavior-summary.md)

## Context

Decision [0045](0045-split-routine-schedule-behavior-and-format.md) split routine schedule behavior from routine format, but the user-facing labels "Fixed" and "Soft" still required too much interpretation.

Users need the form to explain what will happen in task rows and task details after the behavior is selected.

## Decision

Routine forms label the fixed schedule behavior as "Due" and the soft schedule behavior as "Gentle".

- Due means the routine can become due or overdue.
- Gentle means the routine stays visible and can be nudged again without overdue pressure.
- Decision [0180](0180-clarify-schedule-behavior-summary.md) later narrows the preview to expected row badges plus one concise explanatory line, avoiding extra cadence or availability explanation inside the badge preview.
- Internal enum cases and persisted `RoutineScheduleMode` values keep their existing fixed/soft naming to avoid data migration and preserve domain semantics in code.
- Quick Add can continue accepting "soft" and "softly" as input syntax, while app-facing result copy should describe the created routine as Gentle.

## Consequences

The product language becomes clearer without changing recurrence behavior or storage. Future UI copy should use Due/Gentle for user-facing schedule behavior labels, while code can keep using helper properties such as `scheduleBehavior`, `isSoftIntervalRoutine`, and `routineFormat` for implementation logic.
