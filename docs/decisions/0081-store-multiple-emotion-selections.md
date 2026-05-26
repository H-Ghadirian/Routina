# 0081: Store Multiple Emotion Families and Feelings

## Status

Accepted

## Date

2026-05-27

## Context

Emotion states can be mixed. A user may feel fear and anger at the same time, or select several specific feelings within one mood quadrant. The first emotion logger stored one family and one specific feeling, which forced mixed states to be flattened before saving.

## Decision

Emotion logs store ordered lists of selected families and specific feelings. The existing single `familyRawValue` and `label` fields remain as primary compatibility values, while newline-backed multi-value storage preserves the full selection for new logs.

Backup packages include optional family and label arrays for multi-selection restore. Import falls back to the legacy single family and label when those arrays are absent.

## Consequences

- Emotion capture supports selecting more than one family and more than one specific feeling.
- Existing emotion logs and older backups continue to load as one-item selections.
- Timeline, detail, backup/import, and usage-estimate surfaces should read the multi-value fields when presenting or preserving emotion selections.
