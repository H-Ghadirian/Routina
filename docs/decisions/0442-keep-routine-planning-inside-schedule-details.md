# 0442 — Keep Routine Planning Inside Schedule Details

Status: Accepted

Date: 2026-07-27

Refines: [0058 Use Progressive Task Forms](0058-use-progressive-task-forms.md), [0200 Support Task Planned Dates](0200-support-task-planned-dates.md), [0439 Keep Cadence-Dependent Controls After Repeat](0439-keep-cadence-dependent-controls-after-repeat.md)

## Context

Routine planning eligibility depends on cadence. A daily routine does not
support an explicit planned date, while a non-daily routine does. Selecting
`Multi-day` can raise a one-day rolling interval to two days, which makes the
routine non-daily and eligible for Planning.

The Mac form previously responded by adding `Planning` to the distant
`Add More Details` palette. The duration choice and its consequence appeared
in separate cards, and the generic optional-action palette changed even though
the user had only edited schedule behavior.

## Decision

On Mac, eligible routine and compatibility-record Planning belongs inside the
Behavior card's `Schedule details` disclosure. It does not participate in the
standalone optional-section catalog, whether Planning is currently eligible or
not. Changing duration or cadence therefore cannot add or remove a Planning
button in `Add More Details`.

The Planning control appears in `Schedule details` only when the current
routine supports stored planning. Daily routines continue to omit Planning,
and planning eligibility, storage, task-list placement, and runtime semantics
remain unchanged. Cadence-free routines may still expose `Schedule details`
when Planning is the only applicable scheduling control.

One-time todo Planning remains a standalone optional section because todos do
not use the routine Schedule-details disclosure. No explanatory copy is added
beside the Multi-day selector.

## Consequences

- A duration or recurrence edit reveals its planning consequence in the same
  local schedule disclosure.
- The Mac `Add More Details` palette remains stable as routine planning
  eligibility changes.
- Existing routine planned dates are edited in Schedule details instead of a
  separate Planning card.
- The data model and planning rules require no migration.
