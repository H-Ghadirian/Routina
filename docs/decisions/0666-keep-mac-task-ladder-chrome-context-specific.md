# 0666 — Keep Mac Task Ladder chrome context-specific

## Status

Accepted

## Date

2026-08-26

## Refines

- [0188: Prefer self-explanatory UI over instructional copy](0188-prefer-self-explanatory-ui-over-instructional-copy.md)
- [0561: Add a separate Mac task-ranking ladder](0561-add-separate-mac-task-ranking-ladder.md)
- [0565: Collapse macOS Task Ladder value sections](0565-collapse-mac-task-ladder-value-sections.md)
- [0576: Offer direct repeating-task Ladder activation](0576-offer-direct-repeating-task-ladder-grouping.md)
- [0632: Integrate Mac workspaces in the main window](0632-integrate-mac-workspaces-in-the-main-window.md)
- [0634: Unify Mac workspace search and creation](0634-unify-mac-workspace-search-and-creation.md)

## Context

After Task Ladder moved into the main Mac window, its root workspace name was
visible in the global workspace menu, the Ladder control bar, and the list-pane
header at the same time. The selected sort direction was likewise visible in a
button, repeated in a subtitle, and potentially repeated as an estimated-time
section title. Group creation, missing-value sections, and container details
also repeated `Task Ladder`, `Group`, `Separate`, or explanatory wording after
their surrounding context had already established that meaning.

The controls were individually accurate, but their adjacent layers made the top
of the workspace tall and verbally noisy. Nested scope still needs a local name
and back route, and factual/read-only behavior still needs accessible explanation.

## Decision

- The global workspace menu is the sole visible root `Task Ladder` title.
- Task Ladder's compact control bar owns the metric, optional Base/Now choice,
  direction, current item or match count, `Add Group` action, and refresh.
- The root list starts directly with value sections. A local title/back row is
  inserted only for a nested group and names that group without another sort or
  count summary.
- Direction appears visibly in the direction control once. The list removes its
  direction/instruction subtitle, and estimated-time sections use `Has estimate`
  and `No estimate` instead of restating `Shortest first` or `Longest first`.
- Value-section headers show the value, count, and disclosure only. Read-only
  meaning remains in accessibility and help rather than visible `Read only` or
  `Separate` captions.
- The group-add control is labelled `Add Group`; its menu keeps the explicit
  container-versus-repeating-task choices.
- Container details show the actionable task count and one concise statement
  that contained tasks complete independently, without repeating the workspace
  and container labels.

## Consequences

- The root Ladder gains usable vertical space and a clearer visual hierarchy.
- Every visible label contributes new information rather than echoing a nearby
  toolbar, header, or control.
- Nested navigation remains explicit, and factual/read-only semantics remain
  available to assistive technology and pointer help.
- Ranking, grouping, selection, persistence, search, and completion behavior do
  not change.
