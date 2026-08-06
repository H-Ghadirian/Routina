# 0478: Add Guided iOS Thinking Needed Review

## Status

Accepted

## Date

2026-08-06

## Refines

[0468 Model Task Thinking Needed Separately](0468-model-task-thinking-needed-separately.md),
[0473 Use Guided iOS Missing-Metadata Procedures](0473-use-guided-ios-missing-metadata-procedures.md),
and [0476 Keep Guided Review Card and Detail Work Bounded](0476-keep-guided-review-card-and-detail-work-bounded.md)

## Context

Thinking needed is already independent task metadata, but existing tasks often
still have its neutral `None` value. Opening each task's full editor to
classify that value makes a focused cleanup slow, particularly with a large
task collection.

Pressure already has a compact iOS card flow that presents one eligible task,
its bounded context, direct choices, Skip, and Task Details. Thinking needed
has the same `None` / `Low` / `Medium` / `High` shape and lifecycle rules, so a
separate implementation would risk divergent eligibility and performance.

## Decision

Compact iOS More includes `Add missing Thinking needed data`. It shows one
full-height card at a time for repeating tasks whose typed Thinking needed
value is `None`, plus one-off tasks only while unfinished and uncanceled. The
card shows its title, bounded path/tags/labels context, and direct Low, Medium,
and High choices; selecting a level saves immediately and advances. `Skip`
keeps the task eligible and moves it behind the remaining cards, while `Check
task details` uses the existing Home route. The feature has no macOS entry
point in this release.

Pressure and Thinking needed share a field-parameterized reducer and card view.
The reducer owns the typed predicate, focused next-card loading, mutation,
activity recording, and semantic update notification. It retains only ordered
candidate IDs and the current presentation. The view renders reducer state and
never accesses SwiftData directly. Neutral `None` and values belonging to a
different field are rejected before a save.

Thinking needed remains descriptive metadata: this procedure must not alter
pressure, importance, urgency, priority, duration, scheduling, or ordering.

## Consequences

- Users can classify cognitive effort without losing the focused guided-review
  experience.
- Pressure and Thinking needed follow the same lifecycle and performance
  boundaries, without duplicated data-loading code.
- A saved Thinking needed choice remains independent of all priority-related
  metadata and task planning behavior.
