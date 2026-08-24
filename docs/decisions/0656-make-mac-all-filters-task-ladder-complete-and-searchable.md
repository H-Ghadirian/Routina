# 0656: Make Mac All Filters Task-Ladder Complete and Searchable

## Status

Accepted

## Date

2026-08-24

## Revises

- [0364: Rename Shared Mac Filter Scope to All](0364-rename-shared-mac-filter-scope-to-all.md)
- [0563: Present Importance and Urgency as Independent Task Controls](0563-present-importance-and-urgency-as-independent-task-controls.md)

## Refines

- [0391: Filter Task List by Duration Estimates](0391-filter-task-list-by-duration-estimates.md)
- [0418: Keep Whole-History Work Out of Scrolling Render Paths](0418-keep-whole-history-work-out-of-scrolling-render-paths.md)
- [0468: Model Task Thinking Needed Separately](0468-model-task-thinking-needed-separately.md)
- [0532: Defer the iOS Home Filter Tag Catalog](0532-defer-ios-home-filter-tag-catalog.md)
- [0579: Align iOS Filter Tag Picker With Task Tag Picker](0579-align-ios-filter-tag-picker-with-task-tag-picker.md)
- [0649: Give Each Task Ladder Metric an Independent Time Rule](0649-give-each-task-ladder-metric-an-independent-time-rule.md)

## Context

The Mac `All` filter scope covered Task List, Timeline, and task-backed Planner
Calendar items, but it exposed only Tags plus a combined Importance/Urgency
matrix. Pressure, Thinking needed, and Estimated time remained in Task List,
even though all five values describe the same Task Ladder model and people need
one coherent cross-surface way to narrow work.

The Tags card also rendered the entire saved catalog as chips. With dozens of
tags, the filter pane became a long inventory rather than a concise statement
of the active filter.

## Decision

- Mac `All` owns the shared Task Ladder value filters: Importance, Urgency,
  Pressure, Thinking needed, and Estimated time. They apply to Task List,
  task-backed Timeline activity, and task-backed Planner Calendar items.
- Importance, Urgency, and Pressure are independent minimum thresholds.
  Thinking needed is an exact value, and Estimated time selects All, Has
  Estimate, or No Estimate.
- Importance, Urgency, and Pressure match each task's current `Now` value,
  including Changes-over-time derivation. Changes over time remains a way that
  values evolve, not a sixth filter metric.
- When any Task Ladder value filter is active, standalone Timeline entries are
  excluded because they do not own Task Ladder values. Tag-only filtering does
  not impose that exclusion.
- The old Importance/Urgency matrix is removed from this scope. Task List does
  not duplicate Pressure, Thinking needed, or Estimated time controls; it keeps
  only filters specific to task-list presentation and lifecycle.
- The Tags card shows only active included or excluded chips. `All` / `Any`
  appears only when a rule has more than one selected tag. The full catalog is
  available only after `Add tags…` or `Add tags to exclude…` opens a searchable
  picker that pins selected tags, offers a bounded Suggested group, and keeps
  the remaining catalog in a lazy Browse list with counts.
- Tag catalogs, current Task Ladder values, and cross-surface presentations are
  derived and cached outside scrolling row render paths. Daily cache signatures
  account for `Now` values changing with date.

## Consequences

- `All` now means the same Task Ladder constraints on every surface it names.
- People can adjust one metric without reselecting another or translating a
  matrix cell.
- A large tag catalog no longer makes the ordinary filter pane unbounded, while
  deliberate browse and search remain available.
- Timeline makes the absence of Task Ladder metadata deterministic instead of
  silently letting standalone activity pass a task-specific filter.
