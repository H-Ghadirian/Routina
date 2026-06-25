# 0240: Keep Checklist Runout Item Actions Item-Scoped

## Status

Accepted

## Date

2026-06-22

## Refines

- [0186: Put Item Runout in Repeat Type](0186-put-item-runout-in-repeat-type.md)

## Context

Checklist runout routines can have several items due on different dates. Treating one item action as a full routine completion makes the same routine eligible for both done and due list sections when another item is still overdue.

The old `Bought` wording also made item runout feel specific to shopping instead of a generic checklist timing model.

## Decision

Checklist runout item actions are item-scoped:

- The row checkbox resets the selected item's runout date from the action time, then appears checked with a struck-through title until the next day. Unchecking it on that same day restores the item's previous runout state.
- `Extend` temporarily moves the selected item's current due date one day later without recording a routine completion.
- A checklist runout routine records a routine completion only when the action clears all currently due runout items.

Checklist detail rows keep the user's stored item order. Due dates still drive routine availability, status text, notifications, and metadata, but using the checkbox or `Extend` must not reorder the visible checklist rows.

Home list sectioning gives active due/overdue status priority over Done Today so one task cannot render in both sections.

## Consequences

- Completing one runout item no longer creates a Done Today row while other runout items keep the routine due.
- Item rows do not jump after a runout action changes a due date.
- The primary runout item action uses familiar checkbox affordance instead of a text button.
- A same-day mistaken checkbox click can be undone without manually editing the due date.
- Runout routines still count as completed when all due items are reset together.
- User-facing copy for runout actions stays generic instead of purchase-specific.
