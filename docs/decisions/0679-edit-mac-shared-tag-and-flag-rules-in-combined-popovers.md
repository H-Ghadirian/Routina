# 0679: Edit Mac Shared Tag and Flag Rules in Combined Popovers

## Status

Accepted

## Date

2026-08-27

## Revises

- [0671: Present Mac Shared Tags as Direct Actions](0671-present-mac-shared-tags-as-direct-actions.md)
- [0678: Group Mac Shared Tag and Flag Actions](0678-group-mac-shared-tag-and-flag-actions.md)

## Refines

- [0188: Prefer Self-Explanatory UI Over Instructional Copy](0188-prefer-self-explanatory-ui-over-instructional-copy.md)
- [0264: Match Button Hit Areas to Visual Surfaces](0264-match-button-hit-areas-to-visual-surfaces.md)
- [0316: Present Mac Home Filters as a Companion Pane](0316-present-mac-home-filters-as-companion-pane.md)
- [0677: Centralize Mac Flag Filters Under Shared](0677-centralize-mac-flag-filters-under-shared.md)

## Context

Once Shared placed the two Flag actions and the two Tag actions inside titled,
color-backed groups, the separate full-width Include and Exclude buttons repeated
the group identity and made each otherwise compact panel unnecessarily tall. The
searchable popovers already owned the large catalogs, so they were the natural
place to choose which side of a rule was being edited.

Moving all rule information into the popover would make active exclusions easy to
miss. The ordinary panel still needs to communicate every active rule without
requiring inspection.

## Decision

- The titled `Flags` group has one full-width `Edit flag filters…` action, and
  the titled `Tags` group has one full-width `Edit tag filters…` action.
- Each action opens one combined searchable popover with an `Include` / `Exclude`
  segmented choice. Switching the choice updates the Selected, Suggested where
  applicable, and Browse catalog for that side.
- `All` / `Any` editing lives in the popover and appears only when the currently
  selected side contains multiple values.
- Outside the popover, an empty group states that it has no filters. An active
  group shows separate Include and Exclude summaries with directly removable
  chips. The summary includes its All/Any mode only when multiple values make
  that distinction meaningful.
- The group panels remain always expanded. The edit action continues to fill its
  visible surface.
- Matching semantics, mutual exclusion, Flag overlap precedence, persistence,
  cross-surface ownership, counts, colors, suggestions, caching, and the separate
  Stats presentation do not change.

## Consequences

- Each filter family has one clear entry point instead of two visually heavy
  actions.
- Include and Exclude can be edited without opening separate popovers or losing
  the current search context.
- Active exclusions remain visible in the ordinary filter pane and removable in
  one click.
- Choosing the less recently relevant rule side may require one additional click
  after opening the popover, trading a small amount of immediacy for a much more
  compact Shared pane.
