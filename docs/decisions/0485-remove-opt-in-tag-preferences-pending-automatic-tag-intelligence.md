# 0485: Remove Opt-In Tag Preferences Pending Automatic Tag Intelligence

## Status

Accepted

## Date

2026-08-06

## Supersedes

[0482 Use Opt-In Tag Preferences to Refine iOS Task Choice](superseded/0482-use-opt-in-tag-preferences-to-refine-ios-task-choice.md)
and [0483 Progressively Suggest iOS Task-Choice Tags](superseded/0483-progressively-suggest-ios-task-choice-tags.md)

## Context

The opt-in Tag preferences screen and its later contextual prompt require a
person to understand a ranking mechanism before Routina has established useful
evidence. That setup was confusing and does not match the intended experience:
task comparisons should make suggestions easier, not ask the person to manage
the system that may eventually learn from them.

## Decision

Remove the iOS Tag preferences entry, its contextual prompts, learned
selected-tag scores, persistence, cloud sync, backup, rename/delete migration,
and task-choice ranking layer. Existing stored values are left untouched but
are ignored.

Help me choose continues to use explicit task metadata, the selected current
condition, and its separate per-task learned tie-break. Task tags remain
visible context on task surfaces and Mac tag normalization remains independent
under [0484 Confirm Conservative Mac Tag Normalization](0484-confirm-conservative-mac-tag-normalization.md).

Any automatic tag intelligence, including AI-assisted tag-combination
comparisons, requires a separate accepted decision. It must learn from
meaningful choices without asking people to preselect or configure tags.

## Consequences

- Help me choose is simpler and no longer changes recommendations from hidden
  tag-preference data.
- Existing task-choice comparisons retain their per-task learning.
- A future automatic tag-intelligence design starts from clear evidence and
  explainable recommendation behavior rather than extending the removed setup.
