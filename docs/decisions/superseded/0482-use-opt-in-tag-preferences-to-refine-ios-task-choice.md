# 0482: Use Opt-In Tag Preferences to Refine iOS Task Choice

## Status

Superseded by [0485 Remove Opt-In Tag Preferences Pending Automatic Tag Intelligence](../0485-remove-opt-in-tag-preferences-pending-automatic-tag-intelligence.md).

## Date

2026-08-06

## Refines

[0481 Learn Task-Choice Tie-Breaks After Metadata Readiness](../0481-learn-task-choice-tie-breaks-after-metadata-readiness.md)

## Context

Individual task comparisons improve one task at a time. A person often has a
smaller set of meaningful work-area tags—such as Travel or Admin—that can
transfer a learned preference to several tasks. Tags can also be purely
organizational, so using every tag automatically would create misleading
recommendations.

## Decision

Compact iOS More includes `Tag preferences`. The person explicitly selects
the meaningful tags that may refine `Help me choose`; unselected tags have no
effect. Each enabled tag stores a separate learned score and comparison count
in synced, backed-up user preferences. Renaming or deleting a tag preserves or
removes its preference with the tag.

When a person chooses one task over another, Routina updates only the selected
tags unique to the preferred task. Shared tags do not gain a score because the
comparison offers no evidence between them. A task's applicable tag score is
the average of its enabled-tag scores, preventing tasks with many tags from
receiving a mechanical advantage.

Tag preference is a refinement layer: the task-choice reducer ranks explicit
Importance, Urgency, Pressure, Thinking needed, duration, and the current
condition first. It then uses tag preference before the individual task
tie-break. It asks another comparison only when both the metadata score and
tag-preference score remain tied. Tag scores never alter visible task metadata,
priority, duration, planning, scheduling, or task order.

The management UI is iOS-only for this MVP. The stored setting still syncs and
backs up so an iPhone restore does not lose the learned preferences; macOS has
no entry point and does not use this layer.

## Consequences

- One comparison can improve the ordering of several similarly described
  tasks that share a meaningful enabled tag.
- People retain control over which tags participate in recommendations and can
  reset learned scores without removing their selected tags.
- Core urgency and importance remain explainable and cannot be overridden by
  a tag preference.
