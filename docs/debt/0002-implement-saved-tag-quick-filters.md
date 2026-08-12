# 0002 — Implement saved-tag quick filters

Status: Deferred

## Current State

Routina has durable support for a person's selected saved tags and a Home
action that applies one selected tag as the active task filter. There is no
discoverable shortcut surface that sends that action, so Settings -> Tags must
not offer an `Add to quick filters` control or report a quick-filter count.

The stored preference and reducer support remain for backup and sync
compatibility and as a starting point for the future implementation. Existing
saved values have no visible effect while this ticket is deferred.

## Target State

Offer a clear, discoverable saved-tag shortcut surface in iOS Home. People can
choose the saved tags that appear there and use a shortcut to show Home tasks
with that tag, without needing to open the full filter sheet first.

## Required Implementation Work

- Choose the Home placement, capacity, ordering, and empty state for the
  shortcut surface; do not expose configuration before this destination exists.
- Connect each shortcut to `AppFeature.homeFastFilterSelected`, then verify the
  existing Home action applies the selected tag and clears incompatible optional
  filters consistently.
- Give each shortcut an explicit label and full visual hit area, including an
  accessible selected-state description and a way to clear or replace the
  active shortcut filter.
- Add end-to-end coverage for configuring a tag, reaching it from Home, and
  restoring or removing it through settings, backup, and sync.

## Safeguard While Deferred

Do not add a saved-tag quick-filter configuration affordance, count, or icon
unless a person can immediately reach and use the corresponding shortcut.
