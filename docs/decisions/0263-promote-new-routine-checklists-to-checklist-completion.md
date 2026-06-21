# 0263: Promote New Routine Checklists to Checklist Completion

## Status

Accepted

## Date

2026-06-21

## Refines

- [0175: Use Routine Finish Mode for Checklist Creation](0175-use-routine-finish-mode-for-checklist-creation.md)
- [0259: Allow Daily Checklist Auto-Assumed Completion](0259-allow-daily-checklist-auto-assumed-completion.md)

## Context

Decision 0175 kept existing checklist items visible on Standard routines so older optional checklist data would not be hidden or lost. That compatibility path also allowed a routine that started without checklist items to gain checklist items in Task Details while remaining in Standard completion.

That state is confusing for daily routines because decision 0259 intentionally makes auto-assume done eligible for daily Checklist-completion routines, but not for Standard routines with optional checklist items.

## Decision

When Task Details adds checklist items to a routine that previously had no checklist items, the editor promotes Standard completion to Checklist completion as long as doing so will not discard sequential steps.

Existing Standard routines that already carry checklist items remain readable and editable as legacy optional checklist data.

## Consequences

- Newly-created routine checklists use the routine finish behavior that matches their data.
- Daily checklist routines can expose auto-assume done eligibility immediately after adding the first checklist item.
- Legacy Standard-plus-checklist routines remain compatible and are not silently rewritten unless the user changes the finish mode.
