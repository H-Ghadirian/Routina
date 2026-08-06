# 0481: Learn Task-Choice Tie-Breaks After Metadata Readiness

## Status

Accepted

## Date

2026-08-06

## Supersedes

[0479 Use Bounded Pairwise Comparisons for iOS Task Choice](0479-use-bounded-pairwise-comparisons-for-ios-task-choice.md)

## Context

The original task-choice flow discarded each comparison and chose from a
six-task shortlist. That cannot improve later recommendations, and it can give
a recommendation before the person has supplied the information needed to
compare their active tasks fairly. Comparing every possible task pair would be
too much work, especially for hundreds of tasks.

## Decision

`Help me choose` now requires every currently selectable task to have explicit
Importance, explicit Urgency, Pressure, Thinking needed, and a time estimate
before it can recommend a task. It reports the missing-field counts and sends
the person to the existing More review procedures rather than guessing from
default or absent values.

Task-choice comparisons persist two task-choice-only values: a learned
tie-break `Double` and a comparison count. These values are backed up and
synced with the task, but are not shown as Importance, Urgency, Pressure,
Thinking needed, Priority, duration, planning, scheduling, or task order.
When a person chooses a task, its learned score advances one tenth above the
higher score in that pair. This creates an ordering among otherwise equally
relevant tasks without changing what their descriptive metadata means.

For a selected time, energy, and intent, the reducer first ranks all eligible
tasks by their explicit metadata. It asks only when two tasks share the same
condition-aware metadata score and the same learned tie-break. After each
answer, it reloads reducer-owned data and asks the next unresolved tie. For
example, if A beats B, then C beats B, both A and C reach `0.1`; the next
comparison is A versus C. A direct suggestion appears only after every
condition-relevant tie is resolved. The SwiftUI view holds only the visible
pair or final recommendation; it performs no SwiftData work.

## Consequences

- Recommendations become durable across Help me choose sessions without
  redefining visible task metadata.
- A person completes missing-data reviews once before relying on a suggestion.
- The adaptive comparison flow never schedules an all-pairs review upfront;
  it continues only while a tie can still change the recommendation.
- Adding or editing a task can create a new unresolved tie, which naturally
  returns the person to a short comparison before the next direct suggestion.
