# 0138: Support a Tired Emotion Quick Log

## Status

Accepted

## Date

2026-06-03

## Context

Emotion capture asks users to choose pleasantness, energy, families, specific feelings, body areas, notes, and context links. That structure works for mixed emotions, but a common low-energy state like needing more sleep is awkward to translate by hand. Users should not have to decide whether tiredness is a sleep record, an emotion, a body cue, or a reflection before they can capture it.

Sleep already remains dedicated `SleepSession` data, while emotion logs can optionally link to sleep sessions. The improvement should keep those data boundaries intact.

## Decision

The emotion editor includes a quick log for "Tired / need sleep." Choosing it sets the emotion to unpleasant, low energy, selects Sadness with the specific feeling "tired," marks Energy as the body area, adds the reflection "Need more sleep." when the reflection is empty, and links the latest sleep session when one exists and no sleep link is already selected.

The Sadness family includes tired, sleepy, exhausted, and drained as low-energy specific feelings so users can log those states through the normal picker as well.

## Consequences

- Tiredness can be captured as an emotion/body state without changing the dedicated sleep-session model.
- Users can still edit every field after applying the quick log.
- Recent sleep context is preserved when available, but logging tiredness does not require an existing sleep session.
