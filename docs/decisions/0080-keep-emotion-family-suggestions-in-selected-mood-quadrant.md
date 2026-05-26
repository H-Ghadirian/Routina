# 0080: Keep Emotion Family Suggestions in the Selected Mood Quadrant

## Status

Accepted

## Date

2026-05-27

## Context

Emotion capture now asks for Pleasantness and Energy before suggesting emotion families. If the family suggestions cross the selected pleasant/unpleasant or low/high energy quadrant, the UI becomes confusing; for example, Calm should not appear after selecting Unpleasant and Low energy.

## Decision

Emotion family suggestions stay inside the selected Pleasantness and Energy quadrant:

- Pleasant + high energy: Joy and Surprise/Curiosity
- Pleasant + low energy: Calm
- Unpleasant + high energy: Fear, Anger, Disgust, and Shame/Guilt
- Unpleasant + low energy: Sadness and Shame/Guilt

The mapping follows the app's existing family taxonomy while aligning with the circumplex model distinction between valence and activation.

## Consequences

- Suggested families match the user's selected mood state.
- Calm remains a pleasant, low-energy option only.
- Tests cover the quadrant mapping so future taxonomy changes must update the expected behavior intentionally.
