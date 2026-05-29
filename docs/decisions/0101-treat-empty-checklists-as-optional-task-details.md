# 0101: Treat Empty Checklists as Optional Task Details

## Status

Accepted

## Date

2026-05-29

## Supersedes

[0100: Reveal Task Form Details by Section](0100-reveal-task-form-details-by-section.md) for default checklist visibility only.

## Context

The task form moved optional details behind section-specific reveal actions, but Checklist remained visible by default alongside identity and scheduling. For ordinary task capture, an empty checklist composer still reads like extra setup work even though checklist items are optional for standard routines and todos.

Checklist and runout routine formats are different: they need checklist items to explain or drive completion behavior.

## Decision

Empty optional checklist sections are hidden by default in progressive task forms and appear as a More Details action. Checklist sections remain visible when they already contain checklist content, when there is an in-progress checklist draft, or when the selected routine format requires checklist items.

## Consequences

- New todos and standard routines keep the default form shorter.
- Users can still add a checklist intentionally through More Details.
- Checklist-driven routine formats continue to show checklist controls without an extra reveal step.
