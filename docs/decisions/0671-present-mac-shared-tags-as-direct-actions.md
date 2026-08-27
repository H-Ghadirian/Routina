# 0671: Present Mac Shared Tags as Direct Actions

## Status

Accepted

## Date

2026-08-27

## Refines

- [0188: Prefer Self-Explanatory UI Over Instructional Copy](0188-prefer-self-explanatory-ui-over-instructional-copy.md)
- [0264: Match Button Hit Areas to Visual Surfaces](0264-match-button-hit-areas-to-visual-surfaces.md)
- [0656: Make Mac All Filters Task-Ladder Complete and Searchable](0656-make-mac-all-filters-task-ladder-complete-and-searchable.md)
- [0660: Make Mac Planner Filters Explicit, Composable, and Bounded](0660-make-mac-planner-filters-explicit-composable-and-bounded.md)

## Context

Shared Tags already deferred its potentially large catalog to searchable
popovers, but it still placed two large add actions and repeated empty-state
copy inside a collapsible tinted card. The disclosure added another interaction
before either Include or Exclude could be chosen and consumed substantial space
when no rule was active.

## Decision

- Mac Shared Tags has no disclosure card, Tags header, summary, or empty-state
  copy. Its idle state is two direct teal-tinted actions: `Include tags` and
  `Exclude tags`.
- Each action opens the existing searchable picker. Selected chips appear
  immediately beneath the action they belong to and remain directly removable.
- `All` / `Any` appears beneath those chips only when a rule contains multiple
  tags, because the modes are equivalent for a single tag.
- The action label fills its visible rectangle so the whole surface is
  clickable.
- Tag semantics, persistence, counts, colors, suggestions, lazy catalog browse,
  and mutual exclusion remain unchanged.
- Mac Stats retains the separate collapsible Tags card established by Decision
  0658; this decision changes only the Planner filter surface's Shared scope.

## Consequences

- Shared Tags is immediately actionable and minimal when no rule is active.
- Active include and exclude rules stay visible in the same place without an
  extra disclosure state.
- The large catalog remains absent from ordinary filter rendering and appears
  only when deliberately requested.
- Shared and Stats can reuse the same picker and rule content while presenting
  different outer affordances appropriate to their surfaces.
