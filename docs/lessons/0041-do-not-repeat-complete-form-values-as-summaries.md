# 0041 — Do not repeat complete form values as summaries

Date: 2026-07-26

## Symptom

The unified recurrence composer displayed `Repeat 2 months after completion`
in the editable interval stepper and repeated the same sentence immediately
below it as a passive summary.

## Root Cause

The composer rendered its summary unconditionally for every cadence even when
the active controls already expressed the complete recurrence rule.

## Fix

The presentation policy now suppresses the summary for `After done`. Summaries
remain visible for schedule modes where they explain behavior not fully stated
by one editable row.

## Prevention Rule

Do not place passive summary copy directly after a control when it only
restates that control's complete current value. Keep a summary only when it
combines several inputs, explains non-obvious behavior, or communicates
validation state.

## Regression Safeguard

`Tests/macOS/FormSectionTests.swift` verifies that the recurrence summary policy
hides `After done` summaries while preserving the other cadence summaries. The
wide Mac task-form scenario in `docs/scenarios/README.md` records the visible
behavior.
