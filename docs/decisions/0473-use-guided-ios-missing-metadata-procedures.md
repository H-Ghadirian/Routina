# 0473: Use Guided iOS Missing-Metadata Procedures

## Status

Accepted

## Date

2026-08-05

## Context

Existing tasks can legitimately have optional descriptive metadata left at its
neutral value. Editing every such task through the full task form is slow and
can make it hard to focus on one missing value at a time.

The first requested procedure is pressure cleanup: a user needs to find only
tasks whose pressure is still `None`, assign a real pressure value, and move
directly to the next task without scrolling through a dense list. The compact
iOS More tab already owns top-level destinations, while feature data loading
and mutations belong to reducer effects rather than SwiftUI views.

## Decision

Compact iOS More includes an `Add missing Pressure data` destination. It uses a
single, full-height card at a time: task title, the pressure question, and only
the `Low`, `Medium`, and `High` choices. The procedure has no scrolling list
and advances immediately after a successful choice. To make the choice
meaningful without opening the full form, the card also shows a bounded amount
of task context: its custom-section path, up to three tags, and up to three
scheduling or state labels such as `Planned today`, `Due tomorrow`, or
`Blocked`. Each card also offers `Skip`, which keeps the task missing and moves
it after the remaining cards, and `Check task details`, which uses the existing
Home task-detail route. When no eligible tasks remain, it presents a simple
completion state.

Eligibility is exact: only tasks whose typed pressure value is `None` are
loaded. The reducer owns the SwiftData fetch and pressure mutation through the
injected model-context dependency, records the normal task-update activity,
and posts the semantic task-update notification after saving. The SwiftUI view
only renders reducer state and sends actions. Task-detail requests travel back
to the app reducer, which selects the existing Home detail rather than creating
a second task-detail presentation path. The reducer derives each card's compact
context from the fetched task, custom-section preference, and injected calendar
and date, so the view still has no persistence or presentation derivation work.
The procedure is not exposed on macOS in this MVP, but its feature logic stays
shared so later iOS-only missing-data procedures can follow the same boundary.

## Consequences

- Users can backfill pressure one task at a time without navigating full forms.
- A typed raw-value comparison protects the procedure from silently missing
  tasks because of storage spelling or casing.
- Skipping never makes an incomplete task look complete; the task remains
  eligible until the user assigns a pressure value.
- Bounded context makes a task identifiable while retaining a simple,
  non-scrolling card surface.
- Additional metadata cleanup procedures require their own product decision;
  this record only establishes pressure as the first procedure.
