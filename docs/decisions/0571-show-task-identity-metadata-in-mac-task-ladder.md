# 0571: Show Task Identity Metadata in the Mac Task Ladder

## Status

Accepted

## Date

2026-08-15

## Context

Every Task Ladder row repeated the selected metric value even though the enclosing
section header already named that value. The repeated text used the row's only
secondary line without helping distinguish tasks inside the same section.

Tags and whether a task repeats are more useful while comparing otherwise similar
tasks. They describe the task itself and remain relevant in every ladder metric.

## Decision

Mac Task Ladder rows show assigned tags as `#tag` labels and show a `Repeating`
label with the repeat symbol for every non-one-off task. They do not repeat the
selected ladder metric or its missing-value fallback in each row. A one-off task
without tags omits the secondary metadata line.

The task-identity metadata is built with the feature's cached ranking presentation
instead of being derived repeatedly from SwiftData models while rows render.

## Consequences

- Section headers remain the single visible source for the selected metric value.
- Tags and repeating-task status stay visible while switching between metrics.
- Task data, ladder eligibility, metric values, ordering, and rank persistence do
  not change.
