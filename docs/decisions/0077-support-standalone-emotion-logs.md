# 0077: Support Standalone Emotion Logs

## Status

Accepted

## Date

2026-05-26

## Context

Users may want to capture how they feel without completing a routine or turning the feeling into a task. Emotion capture still benefits from context: a feeling may relate to a note, goal, task, place, or sleep session.

## Decision

Routina stores emotions as standalone `EmotionLog` records. Each record captures a pleasantness and energy position, an emotion family and detail label, intensity, optional body areas, optional reflection text, and optional links to `RoutineNote`, `RoutineGoal`, `RoutineTask`, `RoutinePlace`, and `SleepSession`.

The primary capture controls expose emotion logging independently of routine completion: iOS Home actions include Log Emotion, and the macOS Home add menu includes Emotion. Timeline shows emotion logs as first-class entries under an Emotions filter and opens a dedicated visual detail view. Emotion logs do not generate insight or pattern summaries.

Backup, import, local reset, duplicate cleanup, and cloud usage estimates include emotion logs as owned app data.

## Consequences

- Emotion logging remains a fast standalone capture flow instead of a routine-completion after-step.
- Links give the user context without forcing every emotion into a task or note.
- Timeline can review emotion history alongside tasks, notes, places, and sleep while avoiding automatic interpretation.
