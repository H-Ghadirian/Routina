# 0249: Reset Daily Checklist Progress Each Day

## Status

Accepted

## Date

2026-06-19

## Context

Daily routines can use checklist-completion mode, where each checklist item is progress toward completing today's routine. That progress should help the user finish the current day, but it should not make tomorrow's routine appear partially done.

The previous stored progress was only a set of completed checklist item IDs, with no day attached, so partial progress could survive across days.

## Decision

Checklist-completion progress for daily routines is day-scoped. The app stores the date when the current checklist-progress set starts, counts those checked IDs only on that same day, and clears stale daily checklist progress before the next checklist action or derived-state refresh.

Completed routine history remains in routine logs and `lastDone`; only incomplete daily checklist-progress state resets.

## Consequences

- A daily checklist routine starts each new day with every checklist item visually unchecked.
- Partial checklist progress still persists during the current day.
- Non-daily checklist-completion routines can keep their in-progress checklist state across days.
- Optional checklist progress remains durable and is not treated as daily routine completion progress.
