# 0586: Group iOS Task Detail Priority Context in the Header

## Status

Accepted

## Date

2026-08-16

## Refines

- [0468: Model Task Thinking Needed Separately](0468-model-task-thinking-needed-separately.md)
- [0563: Present Importance and Urgency as Independent Task Controls](0563-present-importance-and-urgency-as-independent-task-controls.md)

## Context

iOS Task Details presented Importance, Urgency, and Pressure together in the task header, but placed Thinking needed inside the separate primary-action card. The split made four closely related task-selection signals harder to scan and made Thinking appear connected to completion rather than descriptive task context.

## Decision

iOS Task Details presents the independently editable picker pills together in this header order: Importance, Urgency, Pressure, then Thinking needed. Thinking retains its independent meaning and persistence; only its presentation location changes.

The todo State control remains in the todo primary-action card, and the completion control remains the primary action for both todos and routines. macOS presentation is unchanged.

## Consequences

- The four task-selection signals can be scanned and edited in one predictable place.
- Thinking needed no longer competes with or appears to qualify the primary completion action.
- Existing optional visibility and `Add more details` behavior remain unchanged.
