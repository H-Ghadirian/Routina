# 0184: Label Month-Day Fallbacks Explicitly

- **Status:** Accepted
- **Date:** 2026-06-07
- **Refines:** [0177](0177-separate-interval-and-calendar-repeat-controls.md)

## Context

Monthly calendar routines allow choosing days 1 through 31. The recurrence date math already clamps invalid days to the last valid day of the target month, so a routine configured for day 31 runs on April 30, February 28 or 29, and so on.

The form still said `Day 31 of each month`, which implies every month has a 31st and hides the existing fallback behavior.

## Decision

Month-day recurrence presentation must name the fallback behavior:

- Day 31 is presented as `Last day of each month`.
- Days 29 and 30 remain selectable, but their labels and summaries mention that shorter months use their last day.
- Date math and persisted recurrence values remain unchanged: the stored day stays 1...31, and each target month clamps that value to its valid day range.

## Consequences

Users see what will actually happen before saving the routine. Existing tasks keep their stored recurrence day, while form labels, summaries, and display text explain the shorter-month fallback instead of implying impossible dates.
