# 0557: Build iOS Search Presentations Off the Main Actor

## Status

Accepted

## Date

2026-08-12

## Refines

- [0418: Keep Whole-History Work Out of Scrolling Render Paths](0418-keep-whole-history-work-out-of-scrolling-render-paths.md)
- [0541: Keep iOS Search Input Ahead of Home Presentations](0541-keep-ios-search-input-ahead-of-home-presentations.md)
- [0544: Scope iOS Search Field to Dedicated Search Tab](0544-scope-ios-search-field-to-dedicated-search-tab.md)

## Context

The applied-query debounce kept every keystroke from rebuilding Home, but the
eventual filtered, sorted, and sectioned presentation still ran synchronously
on the main actor. With a production-scale task catalog, that work could block
keyboard delivery and the native Search-tab transition after the debounce.
Search matching also repeatedly normalized every searchable task field during
each full-catalog pass.

## Decision

Home display snapshots carry one pre-normalized search index containing the
same name, emoji, description, notes, place, tag, Flag, and Goal vocabulary as
before. Each applied iOS query normalizes once and searches that immutable
index.

The active iOS Home or Search destination captures its value snapshot and
filtering configuration on the main actor, then builds non-actionable
presentations in a cancellable user-initiated detached task. SwiftData model
instances are removed from the detached request; actionable filtering, which
still depends on those actor-bound models, remains on the main actor. A
cancelled or superseded build never replaces the current presentation.

The iOS task-list container remains mounted when Search moves between results
and an empty state. Only the empty-state overlay receives the short opacity
animation; a presentation revision does not implicitly animate the complete
list hierarchy. Row-number lookup dictionaries for large restored
presentations also build in cancellable user-initiated detached work and are
published only after the current build completes.

Visible iOS row metadata derives its scalar elapsed-time and urgency values
directly from the immutable display plus a reference date. Row rendering must
not reconstruct the complete Home filtering configuration or copy shared Home
state merely to format a visible row.

## Consequences

- Rapid typing, Search-tab expansion, and keyboard animation do not wait for a
  full task-list filter, sort, or section build.
- Superseded background builds cooperate with cancellation, and only the
  current query may publish results.
- Search result and empty-state replacement preserves the native list host and
  limits the short opacity transition to the empty-state overlay.
- Clearing Search does not rebuild a full-catalog row-number dictionary on the
  main actor while the keyboard and restored rows animate.
- Visible row metadata no longer reconstructs Home filtering state during
  SwiftUI row rendering.
- Display snapshot creation performs a small one-time indexing cost and retains
  the bounded normalized text for reuse by later queries.
- Future detached presentation work must cross the actor boundary with value
  snapshots only; SwiftData models remain actor-bound.
