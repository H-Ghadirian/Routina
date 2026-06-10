# 0203 Place Not Today in Plan To Do Menu

Status: Accepted

Date: 2026-06-10

Refines: [0200 Support Task Planned Dates](0200-support-task-planned-dates.md)

## Context

`Not today` is a temporary planning choice for an active routine: it removes the routine from today's working list and brings it back tomorrow. Keeping it as a top-level row context-menu action made it feel separate from other "when should this appear?" choices.

## Decision

Task row context menus present `Not today` inside the `Plan to do` menu rather than as a top-level lifecycle action.

Daily routines still do not expose planned-date controls, but their row context menu can show `Plan to do` with only `Not today` because that action is a temporary today-list choice rather than a stored planned date.

## Consequences

The top-level task row menu stays focused on direct task operations like completion, pause, ordering, pinning, and deletion.

Planning-adjacent choices live together under `Plan to do`, while `Not today` continues to use the existing routine snooze behavior and notifications.
