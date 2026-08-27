# 0668 — Separate general Stats and standardize task-type language

Date: 2026-08-27

Status: Accepted

## Context

Add Task and Edit Task already ask people to choose `Repeating` or `One-time`,
but Home, Timeline, Stats, Goals, Settings, and supporting copy still exposed the
persistence terms `Routine` and `Todo`. Stats also placed current inventory
totals beside selected-period activity without identifying that changing the
date range could not change those totals. A one-day `Tasks created per day`
chart used a large chart surface to present only the three category counts.

## Decision

Use `Repeating` and `One-time` for task-type choices and use `repeating task`
and `one-time task` when a noun is needed throughout user-facing presentation.
Keep the persisted `Routine` and `Todo` raw values, schema names, import/backup
keys, and decoding aliases unchanged. Presentation code must map those internal
values to the product vocabulary instead of displaying raw values. Advanced
query and Quick Add accept the new terms while retaining the old terms as
compatibility aliases.

Stats presents two explicit groups:

- `General Stats` contains current task and goal inventory plus reports whose
  own all-time or rolling window is independent of the selected Stats range.
- `Date Range Stats` contains activity, focus, wellbeing, created-task, and
  outcome evidence derived from the selected range. `Missed` remains here with
  `Done` and `Canceled`.

The `Tasks created per day` chart is available only when the selected preset or
custom range covers more than one day. General totals continue to honor active
task filters, but selecting a different date range does not change them.

## Consequences

- Creation, filters, dashboards, task badges, goals, and supporting copy use one
  task-type vocabulary without migrating or invalidating persisted data.
- A person can tell which Stats values are current inventory and which answer a
  question about the selected period.
- Missed activity is not misrepresented as an all-time/current inventory total.
- One-day Stats keeps created-task counts available through ordinary summary
  presentation without rendering a meaningless single-bar trend chart.
- Saved dashboard order is preserved within each scope; the scope boundary is
  stronger than cross-scope ordering.

## Revises

- Revises [0415](0415-support-custom-stats-date-ranges.md): selected boundaries
  govern date-range reports and integrations, while explicitly labeled general
  inventory and independent rolling/all-time reports do not adopt that range.
- Revises the user-facing vocabulary in
  [0642](0642-unify-task-configuration-and-retire-legacy-task-kind-storage.md)
  while preserving its two-kind persistence contract.
