# 0129 Hide Abandoned Focus Sessions from Timeline

- Status: Accepted
- Date: 2026-06-01
- Supersedes: [0126](superseded/0126-show-focus-sessions-in-timeline.md)

## Context

Timeline is the user's evidence surface for activity they want to remember. Showing abandoned focus sessions there makes canceled or accidental timer starts look like accepted focus time, even though Planner already removes abandoned task focus blocks.

## Decision

Timeline shows active, paused, and completed task or unassigned focus sessions as first-class `Focus` entries at their start time. Abandoned `FocusSession` rows stay stored as focus timer history where needed, but they do not render in Timeline in either `All` or `Focus` filters.

Board focus sessions still render from `SprintFocusSessionRecord`; abandoning an active board focus timer removes that record instead of creating abandoned history.

## Consequences

- Accidental or canceled task focus timers no longer leave visible Timeline clutter.
- Timeline focus entries represent active or accepted focus time instead of abandoned attempts.
- Focus stats and recovery workflows can continue to use persisted focus history independently from Timeline presentation.
