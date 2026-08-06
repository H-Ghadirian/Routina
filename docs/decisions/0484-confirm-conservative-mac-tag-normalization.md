# 0484: Confirm Conservative Mac Tag Normalization

## Status

Accepted

## Date

2026-08-06

## Context

Routina already compares tags without case, accent, or spacing differences,
but inflection variants such as `clean` and `Cleaning` remain separate stored
names. Separate variants weaken grouping and any future learned tag signals.
Automatically merging semantic labels risks changing a person's organization
without enough evidence.

## Decision

macOS Settings -> Tags identifies only conservative English word-form variants
(for example singular/plural and base/`-ing` forms). It proposes each merge
individually and performs no change until the person confirms the exact source
and replacement tag.

On confirmation, the existing global tag-rename transaction updates tasks,
goals, enabled notes, and events; it also preserves tag colors and related-tag
rules. If an item already has the replacement tag, its tag list is deduplicated
rather than storing it twice. The existing save, notification, cloud-usage
refresh, backup, and sync behavior remains in effect.

This first step is intentionally local and deterministic. Future AI-assisted
semantic suggestions may extend the candidate list, but they must use the same
explicit confirmation and global-merge path.

## Consequences

- `clean` and `Cleaning` can become one dependable tag without a manual
  task-by-task cleanup.
- The person remains the authority for any potentially destructive merge.
- Ambiguous semantic pairs are not proposed until a later, reviewable AI layer
  can justify them.
