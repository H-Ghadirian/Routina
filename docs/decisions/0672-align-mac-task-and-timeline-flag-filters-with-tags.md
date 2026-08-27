# 0672: Align Mac Task and Timeline Flag Filters With Tags

## Status

Accepted

## Date

2026-08-27

## Refines

- [0264: Match Button Hit Areas to Visual Surfaces](0264-match-button-hit-areas-to-visual-surfaces.md)
- [0418: Keep Whole-History Work Out of Scrolling Render Paths](0418-keep-whole-history-work-out-of-scrolling-render-paths.md)
- [0498: Filter Task Lists by Flags](0498-filter-task-lists-by-flags.md)
- [0582: Hide Flagged Task Activity From Timeline by Default](0582-hide-flagged-task-activity-from-timeline.md)
- [0671: Present Mac Shared Tags as Direct Actions](0671-present-mac-shared-tags-as-direct-actions.md)

## Context

Mac Task List displayed an All/Any segment, an `All Flags` empty chip, and every
remaining Flag under `Add more`. Timeline put similar controls, a `Default
Timeline` chip, the full `Reveal by Flag` catalog, and explanatory copy inside
a collapsible card. With fixed built-in Flags, both presentations repeated
inactive choices and used much more space than the equivalent Tags interaction.

## Decision

- Mac Task List and Timeline use one compact Flag-filter presentation. Its idle
  state is a direct orange-tinted `Include flags` action.
- The action opens a searchable picker that pins selected Flags and lists the
  remaining cached options in Browse. Task List retains its cached counts;
  Timeline retains its pre-hide catalog so hidden activity remains recoverable.
- Selected Flags appear as directly removable chips beneath the action.
  `All` / `Any` appears beneath them only when multiple Flags are selected.
- Task List no longer renders `All Flags`, `Add more`, or the complete available
  catalog inline. Timeline no longer renders a disclosure card, `Default
  Timeline`, `Reveal by Flag`, or its explanatory footer.
- Clearing the last selected chip restores the existing unfiltered Task List or
  default Timeline visibility. Flag matching, persistence, hidden-result
  recovery, and cache boundaries do not change.
- The action's complete visible rectangle is clickable. Mac Stats retains its
  independent include/exclude Flag filter and is not changed by this decision.

## Consequences

- Task List and Timeline Flag filtering now follows the same direct,
  selected-first interaction as Shared Tags.
- Ordinary filter rendering stays independent of catalog size and shows only
  active rules.
- Timeline's exceptional reveal behavior remains deliberate without requiring
  persistent explanatory chrome.
