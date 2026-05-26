# 0082: Edit Emotion Logs From Detail

## Status

Accepted

## Date

2026-05-27

## Context

Emotion logs are standalone timeline records. Users may need to correct the selected feelings, intensity, body areas, reflection, or context links after saving, especially because emotions can be mixed and detailed.

## Decision

Emotion detail views expose an Edit action. Editing reuses the same emotion editor as creation, prefilled from the existing record, and saves changes back to that `EmotionLog` instead of creating a replacement log. Saving an edit updates `updatedAt` so timeline presentations refresh while preserving the original `createdAt`.

## Consequences

- Emotion logs remain first-class editable records.
- Creation and editing share one capture surface and validation path.
- Timeline rows and detail views should refresh when editable emotion fields change.
