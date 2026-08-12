# 0558: Activate iOS Search on Tab Selection

## Status

Accepted

## Date

2026-08-12

## Refines

- [0544: Scope iOS Search Field to the Dedicated Search Tab](0544-scope-ios-search-field-to-dedicated-search-tab.md)

## Context

The dedicated iOS Search tab expanded its native search field when selected,
but SwiftUI's default search activation policy did not focus that field. A
person therefore had to tap Search once to reveal the field and a second time
to open the keyboard. Routina has no Search landing page, recent-search list,
or browse-only content that benefits from keeping the keyboard closed.

## Decision

The stable iOS `TabView` links Search-tab selection to native search activation
with `tabViewSearchActivation(.searchTabSelection)`. Selecting or reselecting
the Search tab focuses the existing native field and opens the keyboard in the
same interaction. The native Close action still dismisses search activation.

The field remains scoped to the dedicated Search tab, and the raw-input,
debounced-query, detached-presentation, and stable-list boundaries remain
unchanged.

## Consequences

- Search is ready for typing after one bottom-tab tap.
- Routina does not reserve the first tap for a discovery surface it does not
  provide.
- Native focus, keyboard, Close, and Search-tab animation behavior remain
  owned by SwiftUI.
- UI tests that leave Search must close its active field before selecting a
  different tab.
