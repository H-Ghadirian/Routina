# 0201: Use Ready to Do for Gentle Ready Badge

- **Status:** Accepted
- **Date:** 2026-06-10
- **Refines:** [0180](0180-clarify-schedule-behavior-summary.md)

## Context

Gentle routines previously used a green `Now` badge before their nudge threshold. Green and `Now` made the state feel urgent or success-like, even though Gentle routines are meant to stay visible without overdue pressure.

## Decision

Gentle routines that are available before their nudge threshold use a neutral gray `Ready to Do` badge.

- Home row metadata should use `Ready to Do` with neutral gray styling for this state.
- Routine schedule behavior previews should teach `Ready to Do` and `Gentle nudge` for Gentle routines.
- `Gentle nudge` remains the post-threshold state and keeps its existing nudge styling.
- Due routine badges, overdue behavior, and Gentle cadence math are unchanged.

## Consequences

Gentle rows read as ready but low-pressure instead of urgent. The form preview and real row badge stay aligned, while the existing Due/Gentle scheduling model does not change.
